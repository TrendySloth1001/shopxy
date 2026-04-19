import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/config/app_config.dart';

class ApiClient {
  ApiClient(this._tokenManager);

  final TokenManager _tokenManager;
  Completer<bool>? _refreshCompleter;

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$normalizedPath');
    return queryParameters == null ? uri : uri.replace(queryParameters: queryParameters);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_tokenManager.accessToken != null)
          'Authorization': 'Bearer ${_tokenManager.accessToken}',
      };

  // ── Public HTTP methods ───────────────────────────────────────────────────

  Future<http.Response> get(String path, {Map<String, String>? queryParameters}) =>
      _withRetry(() => http.get(_buildUri(path, queryParameters), headers: _headers()));

  Future<http.Response> post(String path, {Object? body}) => _withRetry(
        () => http.post(_buildUri(path), headers: _headers(), body: body != null ? jsonEncode(body) : null),
      );

  Future<http.Response> patch(String path, {Object? body}) => _withRetry(
        () => http.patch(_buildUri(path), headers: _headers(), body: body != null ? jsonEncode(body) : null),
      );

  Future<http.Response> delete(String path) =>
      _withRetry(() => http.delete(_buildUri(path), headers: _headers()));

  /// Multipart file upload — includes auth header.
  Future<http.StreamedResponse> multipart(
    String path, {
    required http.MultipartFile file,
    String fieldName = 'file',
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path))
      ..headers['Authorization'] = 'Bearer ${_tokenManager.accessToken ?? ''}'
      ..files.add(file);
    return request.send();
  }

  // ── 401 interception + transparent token refresh ──────────────────────────

  Future<http.Response> _withRetry(Future<http.Response> Function() call) async {
    final response = await call();
    if (response.statusCode != 401) return response;

    final refreshed = await _tryRefresh();
    if (!refreshed) {
      _tokenManager.onUnauthorized?.call();
      return response;
    }
    // Retry original call once with the new token
    return call();
  }

  Future<bool> _tryRefresh() async {
    // Deduplicate concurrent refresh calls
    if (_refreshCompleter != null) return _refreshCompleter!.future;

    _refreshCompleter = Completer<bool>();
    try {
      final rt = await _tokenManager.getRefreshToken();
      if (rt == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final uri = Uri.parse('${AppConfig.apiBaseUrl}auth/refresh');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': rt}),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await _tokenManager.saveTokens(
          accessToken: body['accessToken'] as String,
          refreshToken: body['refreshToken'] as String,
        );
        _refreshCompleter!.complete(true);
        return true;
      } else {
        await _tokenManager.clear();
        _refreshCompleter!.complete(false);
        return false;
      }
    } catch (_) {
      _refreshCompleter?.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}
