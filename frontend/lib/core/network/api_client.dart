import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/config/app_config.dart';

/// Default timeout for every HTTP call. A hung connection on a flaky
/// mobile network would otherwise wedge save buttons + PopScope
/// indefinitely. 20s is comfortably above the slowest legit response
/// we expect (PDF generation), while still bounded.
const Duration _kDefaultTimeout = Duration(seconds: 20);

class ApiClient {
  ApiClient(this._tokenManager);

  final TokenManager _tokenManager;
  Completer<_RefreshOutcome>? _refreshCompleter;

  /// Human device name sent as `X-Device-Name` on every request, so the backend
  /// can label sessions ("Nikhil's iPhone"). Resolved once at startup (async)
  /// and set here; null until then (the backend falls back to the user-agent).
  String? deviceName;

  /// Invoked with the `X-Shop-Perms` version on every authenticated
  /// response. Wired (in main) to AuthProvider so a permission/role
  /// change made elsewhere is picked up on the next request — no
  /// re-login. Null for unauthenticated / customer responses.
  void Function(String permsVersion)? onPermsVersion;

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$normalizedPath');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  Map<String, String> _headers([Map<String, String>? extra]) => {
    'Content-Type': 'application/json',
    if (_tokenManager.accessToken != null)
      'Authorization': 'Bearer ${_tokenManager.accessToken}',
    if (deviceName != null && deviceName!.isNotEmpty)
      'X-Device-Name': deviceName!,
    ...?extra,
  };

  // ── Public HTTP methods ───────────────────────────────────────────────────

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
  }) => _withRetry(
    () => http
        .get(_buildUri(path, queryParameters), headers: _headers())
        .timeout(_kDefaultTimeout),
  );

  /// [extraHeaders] are merged on top of the defaults — used for things
  /// like `X-Idempotency-Key` on submit endpoints.
  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) => _withRetry(
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

  Future<http.Response> delete(String path, {Object? body}) => _withRetry(
    () => http
        .delete(
          _buildUri(path),
          headers: _headers(),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(_kDefaultTimeout),
  );

  /// Multipart file upload — includes auth header AND benefits from the
  /// same 401-retry flow as the JSON helpers. Uploads use a longer
  /// timeout since the body is sent before any response can arrive.
  ///
  /// The file is provided as a *factory* rather than a built
  /// [http.MultipartFile] because [_withRetry] may invoke this closure
  /// twice (the original request + one retry after a token refresh).
  /// A `MultipartFile` is backed by a stream that's consumed by
  /// `request.send()`; reusing the same instance on a retry would throw
  /// "Stream has already been listened to" and surface as a generic
  /// multipart failure to the user. Building a fresh file per attempt
  /// makes the retry path safe.
  Future<http.StreamedResponse> multipart(
    String path, {
    required Future<http.MultipartFile> Function() makeFile,
  }) => _withRetry(() async {
    final request = http.MultipartRequest('POST', _buildUri(path))
      ..headers['Authorization'] = 'Bearer ${_tokenManager.accessToken ?? ''}'
      ..files.add(await makeFile());
    return request.send().timeout(const Duration(seconds: 60));
  });

  // ── 401 interception + transparent token refresh ──────────────────────────

  Future<T> _withRetry<T extends http.BaseResponse>(
    Future<T> Function() call,
  ) async {
    var response = await call();
    if (response.statusCode == 401) {
      // No token attached → nothing to refresh. Return the 401 as-is
      // rather than driving _tryRefresh → onUnauthorized → a spurious
      // logout fan-out (C-AUTH-2, parity with the customer app).
      if (_tokenManager.accessToken == null) {
        return response;
      }
      final outcome = await _tryRefresh();
      switch (outcome) {
        case _RefreshOutcome.ok:
          // Retry original call once with the new token.
          response = await call();
        case _RefreshOutcome.rejected:
          // The server *definitively* refused the refresh token (it was
          // revoked / expired / reused). This is a real end-of-session — log
          // out. `_tryRefresh` has already cleared the stored tokens.
          _tokenManager.onUnauthorized?.call();
          return response;
        case _RefreshOutcome.unavailable:
          // We couldn't even reach the server (timeout / connection drop on a
          // flaky network). This is NOT proof the session is dead, so we must
          // NOT log the user out — that's the "randomly signed out on a
          // hotspot" bug. Keep the session intact and surface the original
          // 401; the next request will retry the refresh.
          return response;
      }
    }
    // Every authenticated response carries the caller's perms version;
    // hand it to the listener so the UI re-syncs when it changes.
    final v = response.headers['x-shop-perms'];
    if (v != null) onPermsVersion?.call(v);
    return response;
  }

  Future<_RefreshOutcome> _tryRefresh() async {
    // Deduplicate concurrent refresh calls — only one network round-trip
    // even when N waiting requests all hit 401 at once.
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<_RefreshOutcome>();
    _refreshCompleter = completer;
    try {
      final rt = await _tokenManager.getRefreshToken();
      if (rt == null) {
        // Nothing to refresh with → the session really is over.
        await _tokenManager.clear();
        completer.complete(_RefreshOutcome.rejected);
        return _RefreshOutcome.rejected;
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
        completer.complete(_RefreshOutcome.ok);
        return _RefreshOutcome.ok;
      }
      // The server answered and refused the token (401/403 = revoked, reused,
      // expired). A definitive end-of-session — drop the dead tokens.
      if (res.statusCode == 401 || res.statusCode == 403) {
        await _tokenManager.clear();
        completer.complete(_RefreshOutcome.rejected);
        return _RefreshOutcome.rejected;
      }
      // Any other status (5xx, 429, a proxy error page, …) is a server-side
      // hiccup, NOT proof the session is dead. Keep the tokens and let the
      // caller retry later rather than logging the user out.
      completer.complete(_RefreshOutcome.unavailable);
      return _RefreshOutcome.unavailable;
    } catch (_) {
      // Timeout / socket drop / malformed body → we never got a verdict from
      // the server. Preserve the session (do NOT clear tokens) so a flaky
      // network can't spuriously sign the user out.
      if (!completer.isCompleted) {
        completer.complete(_RefreshOutcome.unavailable);
      }
      return _RefreshOutcome.unavailable;
    } finally {
      // Only null out the slot if we still own it. Another caller may
      // already have re-entered; we don't want to clobber theirs.
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }
}

/// Result of a token-refresh attempt. The distinction between a *rejected*
/// token (real end-of-session → log out) and an *unavailable* server
/// (transient → keep the session) is what stops a flaky connection from
/// randomly signing the user out.
enum _RefreshOutcome {
  /// New tokens obtained and saved — retry the original request.
  ok,

  /// The server verified and refused the refresh token — session is over.
  rejected,

  /// Couldn't get a verdict (network error / 5xx) — leave the session as-is.
  unavailable,
}
