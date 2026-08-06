import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/network/offline/http_cache.dart';
import 'package:shopxy/core/network/offline/network_status.dart';
import 'package:shopxy/core/network/offline/offline_errors.dart';
import 'package:shopxy/core/network/offline/outbox.dart';
import 'package:shopxy/core/network/offline/resource_policy.dart';

/// Default timeout for every HTTP call. A hung connection on a flaky
/// mobile network would otherwise wedge save buttons + PopScope
/// indefinitely. 20s is comfortably above the slowest legit response
/// we expect (PDF generation), while still bounded.
const Duration _kDefaultTimeout = Duration(seconds: 20);

/// The disk cache stores `response.body` (a String) and replays cache hits
/// as `http.Response(cached.body, ..., headers: {'content-type':
/// 'application/json'})`. `package:http` picks the decode/encode charset from
/// the Content-Type header — utf8 for `application/json`, latin1 for
/// anything else (including `application/pdf`) — so caching a binary
/// response and replaying it with a hardcoded JSON content-type would
/// re-encode it with the wrong charset and corrupt every byte ≥ 0x80 on the
/// next cache hit. Guard every cache write with this so only genuine JSON
/// bodies are ever stored, regardless of what `ResourcePolicy` allows.
bool _isJsonResponse(http.Response response) =>
    (response.headers['content-type'] ?? '').contains('application/json');

class ApiClient {
  ApiClient(
    this._tokenManager, {
    this.cache,
    this.networkStatus,
    this.outbox,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final TokenManager _tokenManager;

  /// The underlying transport. Injected so the client's own logic (cache-first
  /// serve, offline fallback, write-queue routing) is unit-testable with a
  /// `MockClient`; defaults to a real `http.Client` in production.
  final http.Client _http;

  Completer<_RefreshOutcome>? _refreshCompleter;

  /// Device-level response cache (SSOT for offline reads). Null in contexts
  /// that don't wire it (e.g. some tests) → the client behaves online-only.
  final HttpCache? cache;

  /// Connectivity signal updated from request outcomes; drives the offline
  /// banner. Null when not wired.
  final NetworkStatus? networkStatus;

  /// Queue for offline writes (SSOT for pending mutations). Null → writes just
  /// fail offline (Phase 2 behavior). Only naturally-idempotent updates are
  /// ever enqueued; see [_isQueueable].
  final Outbox? outbox;

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

  /// One place that builds every raw HTTP call (single verb switch + timeout +
  /// header assembly), so `get`/`_revalidate`/the write verbs/`sendRaw` don't
  /// each re-implement it. [body] is a pre-encoded JSON string. Not wrapped in
  /// `_withRetry` — callers add that where they want the 401-refresh behavior.
  Future<http.Response> _rawSend(
    String method,
    Uri uri, {
    String? body,
    Map<String, String>? extraHeaders,
  }) {
    final h = _headers(extraHeaders);
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: h).timeout(_kDefaultTimeout);
      case 'POST':
        return _http
            .post(uri, headers: h, body: body)
            .timeout(_kDefaultTimeout);
      case 'PATCH':
        return _http
            .patch(uri, headers: h, body: body)
            .timeout(_kDefaultTimeout);
      case 'PUT':
        return _http.put(uri, headers: h, body: body).timeout(_kDefaultTimeout);
      case 'DELETE':
        return _http
            .delete(uri, headers: h, body: body)
            .timeout(_kDefaultTimeout);
      default:
        throw ArgumentError('Unsupported method: $method');
    }
  }

  // ── Public HTTP methods ───────────────────────────────────────────────────

  /// Broadcasts a resource [tag] (e.g. `products`) whenever a background
  /// revalidation finds the server copy changed. `main` listens once and
  /// reloads the matching provider, so a cache-first paint is followed by a
  /// live repaint — and a change made in another session (web) shows up as soon
  /// as this session revalidates that resource.
  Stream<String> get cacheEvents => _cacheEvents.stream;
  final StreamController<String> _cacheEvents =
      StreamController<String>.broadcast();

  /// A cache entry younger than this is treated as fresh — served without a
  /// background revalidation — so rapid navigation doesn't fire a network
  /// request per screen. Older entries are served instantly AND revalidated.
  static const Duration _staleAfter = Duration(seconds: 20);

  /// Cache keys with a revalidation already in flight, so N concurrent reads of
  /// the same resource trigger at most one background refresh.
  final Set<String> _revalidating = {};

  /// GET with stale-while-revalidate caching + offline fallback.
  ///
  /// - Cache hit → return the cached copy **immediately** (instant paint) and
  ///   revalidate in the background; if the server copy changed, write it and
  ///   emit the resource tag on [cacheEvents] so the provider reloads.
  /// - Cache miss → fetch live (via [_withRetry], so 401-refresh + `x-shop-perms`
  ///   still work), write-through, return.
  /// - Offline (transport failure) with no cache → the original network error
  ///   propagates (unchanged first-open-offline UX).
  ///
  /// A cache-served response deliberately does NOT fire `onPermsVersion` — the
  /// perms version isn't trustworthy offline; the background/next live request
  /// re-supplies it.
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,

    /// Skip the cache-first read (still write-through the fresh response
    /// afterward) — for the rare call site that just performed a write and
    /// needs this read to reflect it *now*, not after the next background
    /// revalidation. Cache-first stays the default: that's what lets the
    /// app cold-boot into the shell offline.
    bool bypassCache = false,
  }) async {
    // Whether this resource is cacheable at all, independent of
    // `bypassCache` — governs the write-through below, so a bypassed read
    // still refreshes the cache for the *next* cache-first read.
    final cacheable = cache != null && ResourcePolicy.isCacheableRead(path);
    final userId = _tokenManager.currentUserId;
    final tag = ResourcePolicy.tagFor(path);
    final uri = _buildUri(path, queryParameters);
    final key = cacheable
        ? cache!.keyFor(
            userId: userId,
            method: 'GET',
            path: path,
            query: queryParameters,
          )
        : null;

    if (cacheable && !bypassCache && key != null) {
      final cached = await cache!.read(key);
      if (cached != null) {
        // Serve instantly. Only revalidate if the copy is old enough to be
        // worth a network round-trip AND no refresh is already running for it
        // (Set.add returns false when the key is already present).
        final stale = DateTime.now().difference(cached.storedAt) >= _staleAfter;
        if (stale && _revalidating.add(key)) {
          unawaited(
            _revalidate(
              uri,
              key: key,
              userId: userId,
              tag: tag,
              previousBody: cached.body,
            ),
          );
        }
        return http.Response(
          cached.body,
          cached.statusCode,
          headers: const {'content-type': 'application/json'},
        );
      }
    }

    try {
      final response = await _withRetry(() => _rawSend('GET', uri));
      networkStatus?.markOnline();
      if (cacheable &&
          key != null &&
          response.statusCode == 200 &&
          _isJsonResponse(response)) {
        unawaited(
          cache!.write(
            key: key,
            userId: userId,
            tag: tag,
            body: response.body,
            statusCode: 200,
          ),
        );
      }
      return response;
    } catch (e) {
      if (isTransportError(e)) networkStatus?.markOffline();
      rethrow;
    }
  }

  /// Background refresh for a cache-first GET. Best-effort: updates the cache
  /// and emits [cacheEvents] only when the body actually changed.
  Future<void> _revalidate(
    Uri uri, {
    required String key,
    required String userId,
    required String tag,
    required String previousBody,
  }) async {
    try {
      final live = await _withRetry(() => _rawSend('GET', uri));
      networkStatus?.markOnline();
      if (live.statusCode == 200 &&
          live.body != previousBody &&
          _isJsonResponse(live)) {
        await cache!.write(
          key: key,
          userId: userId,
          tag: tag,
          body: live.body,
          statusCode: 200,
        );
        if (!_cacheEvents.isClosed) _cacheEvents.add(tag);
      }
    } catch (e) {
      if (isTransportError(e)) networkStatus?.markOffline();
      // Background best-effort — swallow.
    } finally {
      _revalidating.remove(key); // release the in-flight guard
    }
  }

  /// Wraps a mutation: reports connectivity and, on a 2xx, invalidates the
  /// resource's cached reads so the next GET reflects the write (not a
  /// pre-write copy). When offline, routes to the outbox:
  /// - a naturally-idempotent update → enqueue + throw [OfflineWriteQueuedException]
  ///   (a success-ish signal: "saved offline, will sync").
  /// - anything else (POST creates, money/stock) → throw
  ///   [OfflineWriteBlockedException] ("reconnect to complete").
  Future<http.Response> _mutate(
    String method,
    String path,
    String? bodyJson,
    Map<String, String>? headers,
    Future<http.Response> Function() send,
  ) async {
    try {
      final resp = await send();
      networkStatus?.markOnline();
      if (resp.statusCode >= 200 && resp.statusCode < 300) _afterWrite(path);
      return resp;
    } catch (e) {
      if (isTransportError(e)) {
        networkStatus?.markOffline();
        if (outbox != null) {
          if (ResourcePolicy.isQueueableWrite(method, path)) {
            await outbox!.enqueue(
              userId: _tokenManager.currentUserId,
              method: method,
              path: path,
              body: bodyJson,
              headers: headers ?? const {},
            );
            throw OfflineWriteQueuedException(method, path);
          }
          throw OfflineWriteBlockedException(method, path);
        }
      }
      rethrow;
    }
  }

  /// Replay a queued write (used only by the OutboxProcessor). Goes live via
  /// [_withRetry] — it does NOT re-enter the offline-queue logic, so a failed
  /// replay just throws back to the processor. On success, invalidates the
  /// resource cache so the next read is fresh.
  Future<http.Response> sendRaw(
    String method,
    String path, {
    String? body,
    Map<String, String>? headers,
  }) async {
    final resp = await _withRetry(
      () =>
          _rawSend(method, _buildUri(path), body: body, extraHeaders: headers),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) _afterWrite(path);
    return resp;
  }

  /// After a successful write: drop the resource's cached reads AND emit its
  /// tag so the mapped list/dashboard provider reloads in place (whether the
  /// write happened online or via an outbox replay on reconnect).
  void _afterWrite(String path) {
    if (cache == null) return;
    final tag = ResourcePolicy.tagFor(path);
    unawaited(cache!.invalidateTag(_tokenManager.currentUserId, tag));
    if (!_cacheEvents.isClosed) _cacheEvents.add(tag);
  }

  /// [extraHeaders] are merged on top of the defaults — used for things
  /// like `X-Idempotency-Key` on submit endpoints.
  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    final bodyJson = body != null ? jsonEncode(body) : null;
    return _mutate(
      'POST',
      path,
      bodyJson,
      extraHeaders,
      () => _withRetry(
        () => _rawSend(
          'POST',
          _buildUri(path),
          body: bodyJson,
          extraHeaders: extraHeaders,
        ),
      ),
    );
  }

  Future<http.Response> patch(String path, {Object? body}) {
    final bodyJson = body != null ? jsonEncode(body) : null;
    return _mutate(
      'PATCH',
      path,
      bodyJson,
      null,
      () =>
          _withRetry(() => _rawSend('PATCH', _buildUri(path), body: bodyJson)),
    );
  }

  Future<http.Response> put(String path, {Object? body}) {
    final bodyJson = body != null ? jsonEncode(body) : null;
    return _mutate(
      'PUT',
      path,
      bodyJson,
      null,
      () => _withRetry(() => _rawSend('PUT', _buildUri(path), body: bodyJson)),
    );
  }

  Future<http.Response> delete(String path, {Object? body}) {
    final bodyJson = body != null ? jsonEncode(body) : null;
    return _mutate(
      'DELETE',
      path,
      bodyJson,
      null,
      () =>
          _withRetry(() => _rawSend('DELETE', _buildUri(path), body: bodyJson)),
    );
  }

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
    return _http.send(request).timeout(const Duration(seconds: 60));
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
      final res = await _http
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
