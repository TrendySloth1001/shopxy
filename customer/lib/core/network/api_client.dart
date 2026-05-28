import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/config/app_config.dart';

/// Default timeout for every HTTP call. A hung connection on a flaky
/// mobile network would otherwise wedge save buttons + PopScope
/// indefinitely. 20s is comfortably above the slowest legit response
/// we expect, while still bounded.
const Duration _kDefaultTimeout = Duration(seconds: 20);

class ApiClient {
  ApiClient(this._tokenManager);

  final TokenManager _tokenManager;
  Completer<bool>? _refreshCompleter;

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$normalizedPath');
    return queryParameters == null ? uri : uri.replace(queryParameters: queryParameters);
  }

  Map<String, String> _headers([Map<String, String>? extra]) => {
        'Content-Type': 'application/json',
        if (_tokenManager.accessToken != null)
          'Authorization': 'Bearer ${_tokenManager.accessToken}',
        ...?extra,
      };

  // ── Public HTTP methods ───────────────────────────────────────────────────

  Future<http.Response> get(String path, {Map<String, String>? queryParameters}) =>
      _withRetry(() => http
          .get(_buildUri(path, queryParameters), headers: _headers())
          .timeout(_kDefaultTimeout));

  /// [extraHeaders] are merged on top of the defaults — used for things
  /// like `X-Idempotency-Key` on cart submit so a flaky retry doesn't
  /// double-book the customer.
  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) =>
      _withRetry(
        () => http
            .post(
              _buildUri(path),
              headers: _headers(extraHeaders),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_kDefaultTimeout),
      );

  Future<http.Response> patch(String path, {Object? body}) => _withRetry(
        () => http
            .patch(
              _buildUri(path),
              headers: _headers(),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_kDefaultTimeout),
      );

  Future<http.Response> put(String path, {Object? body}) => _withRetry(
        () => http
            .put(
              _buildUri(path),
              headers: _headers(),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_kDefaultTimeout),
      );

  // Body-bearing DELETE kept in sync with the merchant ApiClient even
  // though the customer app doesn't currently use the body slot —
  // CLAUDE.md's "duplicate, don't extract" rule says the two clients
  // stay structurally identical so a future caller doesn't trip on
  // missing parity.
  Future<http.Response> delete(String path, {Object? body}) => _withRetry(
        () => http
            .delete(
              _buildUri(path),
              headers: _headers(),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_kDefaultTimeout),
      );

  /// Multipart file upload — includes auth header. Takes a *factory*
  /// (not a built [http.MultipartFile]) because [_withRetry] may invoke
  /// this closure twice — once for the original request, once after a
  /// silent token refresh. A MultipartFile's stream is consumed by
  /// `request.send()`, so reusing the same instance on a retry would
  /// throw "Stream has already been listened to" and surface as a
  /// generic multipart failure to the user. Rebuilding per attempt
  /// keeps the retry path safe.
  Future<http.StreamedResponse> multipart(
    String path, {
    required Future<http.MultipartFile> Function() makeFile,
  }) =>
      _withRetry(() async {
        final request = http.MultipartRequest('POST', _buildUri(path))
          ..headers['Authorization'] = 'Bearer ${_tokenManager.accessToken ?? ''}'
          ..files.add(await makeFile());
        return request.send().timeout(const Duration(seconds: 60));
      });

  // ── 401 interception + transparent token refresh ──────────────────────────

  Future<T> _withRetry<T extends http.BaseResponse>(Future<T> Function() call) async {
    final response = await call();
    if (response.statusCode != 401) return response;

    final refreshed = await _tryRefresh();
    if (!refreshed) {
      _tokenManager.onUnauthorized?.call();
      return response;
    }
    // Retry original call once with the new token.
    return call();
  }

  Future<bool> _tryRefresh() async {
    // Deduplicate concurrent refresh calls — only one network round-trip
    // even when N waiting requests all hit 401 at once.
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final rt = await _tokenManager.getRefreshToken();
      if (rt == null) {
        completer.complete(false);
        return false;
      }

      final uri = Uri.parse('${AppConfig.apiBaseUrl}auth/refresh');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': rt}),
          )
          .timeout(_kDefaultTimeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await _tokenManager.saveTokens(
          accessToken: body['accessToken'] as String,
          refreshToken: body['refreshToken'] as String,
        );
        completer.complete(true);
        return true;
      } else {
        await _tokenManager.clear();
        completer.complete(false);
        return false;
      }
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
      return false;
    } finally {
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }
}
