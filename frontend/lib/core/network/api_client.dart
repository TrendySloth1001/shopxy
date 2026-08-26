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

const Duration _kDefaultTimeout = Duration(seconds: 20);

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

  final http.Client _http;

  Completer<_RefreshOutcome>? _refreshCompleter;

  final HttpCache? cache;

  final NetworkStatus? networkStatus;

  final Outbox? outbox;

  String? deviceName;

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

  Stream<String> get cacheEvents => _cacheEvents.stream;
  final StreamController<String> _cacheEvents =
      StreamController<String>.broadcast();

  static const Duration _staleAfter = Duration(seconds: 20);

  final Set<String> _revalidating = {};

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,

    bool bypassCache = false,
  }) async {
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
    } finally {
      _revalidating.remove(key);
    }
  }

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

  void _afterWrite(String path) {
    if (cache == null) return;
    final tag = ResourcePolicy.tagFor(path);
    unawaited(cache!.invalidateTag(_tokenManager.currentUserId, tag));
    if (!_cacheEvents.isClosed) _cacheEvents.add(tag);
  }

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

  Future<http.StreamedResponse> multipart(
    String path, {
    required Future<http.MultipartFile> Function() makeFile,
  }) => _withRetry(() async {
    final request = http.MultipartRequest('POST', _buildUri(path))
      ..headers['Authorization'] = 'Bearer ${_tokenManager.accessToken ?? ''}'
      ..files.add(await makeFile());
    return _http.send(request).timeout(const Duration(seconds: 60));
  });

  Future<T> _withRetry<T extends http.BaseResponse>(
    Future<T> Function() call,
  ) async {
    var response = await call();
    if (response.statusCode == 401) {
      if (_tokenManager.accessToken == null) {
        return response;
      }
      final outcome = await _tryRefresh();
      switch (outcome) {
        case _RefreshOutcome.ok:
          response = await call();
        case _RefreshOutcome.rejected:
          _tokenManager.onUnauthorized?.call();
          return response;
        case _RefreshOutcome.unavailable:
          return response;
      }
    }
    final v = response.headers['x-shop-perms'];
    if (v != null) onPermsVersion?.call(v);
    return response;
  }

  Future<_RefreshOutcome> _tryRefresh() async {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<_RefreshOutcome>();
    _refreshCompleter = completer;
    try {
      final rt = await _tokenManager.getRefreshToken();
      if (rt == null) {
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
      if (res.statusCode == 401 || res.statusCode == 403) {
        await _tokenManager.clear();
        completer.complete(_RefreshOutcome.rejected);
        return _RefreshOutcome.rejected;
      }
      completer.complete(_RefreshOutcome.unavailable);
      return _RefreshOutcome.unavailable;
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(_RefreshOutcome.unavailable);
      }
      return _RefreshOutcome.unavailable;
    } finally {
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }
}

enum _RefreshOutcome {
  ok,

  rejected,

  unavailable,
}
