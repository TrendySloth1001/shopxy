import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A cached response body + the bits of metadata needed to replay it.
class CachedResponse {
  const CachedResponse({
    required this.body,
    required this.statusCode,
    required this.storedAt,
  });

  final String body;
  final int statusCode;
  final DateTime storedAt;
}

/// Metadata kept in memory (and mirrored to `index.json`) for every cache
/// entry. The body itself lives in a sibling file named `<hash>` so we don't
/// parse large payloads just to run LRU bookkeeping.
class _Meta {
  _Meta({
    required this.userId,
    required this.tag,
    required this.statusCode,
    required this.storedAt,
    required this.bytes,
  });

  final String userId;

  /// Resource group (e.g. `products`, `invoices`) — lets a successful write
  /// invalidate every cached read for that resource, and lets a background
  /// revalidation broadcast which resource changed.
  final String tag;
  final int statusCode;
  final DateTime storedAt;
  final int bytes;

  Map<String, dynamic> toJson() => {
    'u': userId,
    'g': tag,
    's': statusCode,
    't': storedAt.millisecondsSinceEpoch,
    'n': bytes,
  };

  static _Meta? fromJson(Object? j) {
    if (j is! Map) return null;
    final u = j['u'], g = j['g'], s = j['s'], t = j['t'], n = j['n'];
    if (u is! String || s is! int || t is! int || n is! int) return null;
    return _Meta(
      userId: u,
      tag: g is String ? g : '',
      statusCode: s,
      storedAt: DateTime.fromMillisecondsSinceEpoch(t),
      bytes: n,
    );
  }
}

/// Single source of truth for cached HTTP GET responses on the device.
///
/// - Per-user namespaced keys ([_hash] mixes the userId in) so one account's
///   cached business data can never surface for another.
/// - Bodies persist as individual files under
///   `getApplicationSupportDirectory()/http_cache/`; a small `index.json` holds
///   metadata + insertion order for LRU eviction.
/// - Every method is best-effort: an I/O failure degrades to a cache miss / a
///   skipped write and never throws into the request path.
///
/// **At-rest storage (deliberate).** Bodies are stored as plaintext JSON in the
/// app-private support directory, NOT in `flutter_secure_storage`. Secure
/// storage is for small secrets (the auth tokens live there); it is unsuitable
/// for bulk payloads. Threat model: the OS sandbox already isolates this dir
/// from other apps; the sensitive *secrets* (tokens) are never cached here, and
/// live-only endpoints (`/auth/me`, sessions) are denylisted in
/// `ResourcePolicy` so identity data isn't persisted. Full at-rest encryption
/// of cached business data would need a crypto dependency + a key sealed in
/// secure storage — a reasonable future hardening step, out of scope here.
class HttpCache {
  HttpCache({int maxEntries = 600, int maxBytes = 12 * 1024 * 1024})
    : _maxEntries = maxEntries,
      _maxBytes = maxBytes;

  final int _maxEntries;
  final int _maxBytes;

  Directory? _dir;
  // Insertion-ordered: first = least-recently-used. A read re-inserts at the end.
  final LinkedHashMap<String, _Meta> _index = LinkedHashMap();
  int _totalBytes = 0;

  final Completer<void> _ready = Completer<void>();
  bool _usable = false;
  // Serialize index.json writes so concurrent revalidations don't corrupt it.
  Future<void> _indexWrite = Future.value();
  // Debounce index persistence: a burst of writes (e.g. a dashboard load hitting
  // many endpoints) coalesces into one flush instead of rewriting index.json
  // per entry.
  Timer? _persistTimer;
  static const Duration _persistDebounce = Duration(milliseconds: 500);

  /// Resolve the cache dir and load the index. Call once at startup (awaited).
  /// Safe to call before use — every method awaits [_ready].
  Future<void> init() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/http_cache');
      await dir.create(recursive: true);
      _dir = dir;
      await _loadIndex();
      _usable = true;
    } catch (e) {
      // Cache unavailable (e.g. no writable dir) — run as a no-op cache.
      _usable = false;
      if (kDebugMode) debugPrint('HttpCache: disabled ($e)');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _loadIndex() async {
    final file = File('${_dir!.path}/index.json');
    if (!await file.exists()) return;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      raw.forEach((k, v) {
        final meta = _Meta.fromJson(v);
        if (k is String && meta != null) {
          _index[k] = meta;
          _totalBytes += meta.bytes;
        }
      });
    } catch (_) {
      // Corrupt index → start clean (bodies become orphans, pruned over time).
      _index.clear();
      _totalBytes = 0;
    }
  }

  /// Stable per-user cache key. FNV-1a/64 → hex; deterministic across launches
  /// (unlike `String.hashCode`), collision-resistant enough for a device cache.
  String keyFor({
    required String userId,
    required String method,
    required String path,
    Map<String, String>? query,
  }) {
    final q = (query == null || query.isEmpty)
        ? ''
        : (query.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key)))
              .map((e) => '${e.key}=${e.value}')
              .join('&');
    return _hash('$userId|$method|$path|$q');
  }

  static String _hash(String s) {
    // FNV-1a 64-bit.
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xFFFFFFFFFFFFFFFF;
    for (final unit in s.codeUnits) {
      hash = (hash ^ unit) & mask;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Read a cached body by key. Bumps it to most-recently-used. Returns null on
  /// miss, corrupt entry, or if the cache is disabled.
  Future<CachedResponse?> read(String key) async {
    await _ready.future;
    if (!_usable) return null;
    final meta = _index[key];
    if (meta == null) return null;
    // Bump to MRU *synchronously*, before the await — otherwise a concurrent
    // write/_evict during the file read could remove this key and our later
    // re-insert would resurrect a stale entry (and skew _totalBytes).
    _index.remove(key);
    _index[key] = meta;
    try {
      final body = await File('${_dir!.path}/$key').readAsString();
      // The entry may have been evicted while we read (rare); only return it if
      // it's still current.
      if (!identical(_index[key], meta)) return null;
      return CachedResponse(
        body: body,
        statusCode: meta.statusCode,
        storedAt: meta.storedAt,
      );
    } catch (_) {
      // Body missing/corrupt → drop the dangling index entry (if still ours).
      if (identical(_index[key], meta)) {
        _index.remove(key);
        _totalBytes -= meta.bytes;
      }
      return null;
    }
  }

  /// Write-through a fresh response. Best-effort; never throws.
  Future<void> write({
    required String key,
    required String userId,
    required String tag,
    required String body,
    required int statusCode,
  }) async {
    await _ready.future;
    if (!_usable) return;
    try {
      final bytes = utf8.encode(body).length;
      await File('${_dir!.path}/$key').writeAsString(body, flush: false);
      final prev = _index.remove(key);
      if (prev != null) _totalBytes -= prev.bytes;
      _index[key] = _Meta(
        userId: userId,
        tag: tag,
        statusCode: statusCode,
        storedAt: DateTime.now(),
        bytes: bytes,
      );
      _totalBytes += bytes;
      await _evict();
      _persistIndex();
    } catch (_) {
      // Ignore — a failed cache write must not affect the request.
    }
  }

  /// Drop every cached read for one resource group of one user — called after a
  /// successful write so the next read reflects the change instead of serving a
  /// pre-write copy. Best-effort.
  Future<void> invalidateTag(String userId, String tag) async {
    await _ready.future;
    if (!_usable) return;
    final doomed = [
      for (final e in _index.entries)
        if (e.value.userId == userId && e.value.tag == tag) e.key,
    ];
    if (doomed.isEmpty) return;
    for (final key in doomed) {
      final meta = _index.remove(key);
      if (meta != null) _totalBytes -= meta.bytes;
      try {
        await File('${_dir!.path}/$key').delete();
      } catch (_) {}
    }
    _persistIndex();
  }

  /// Evict least-recently-used entries until under both caps.
  Future<void> _evict() async {
    while (_index.length > _maxEntries || _totalBytes > _maxBytes) {
      final lruKey = _index.keys.first;
      final meta = _index.remove(lruKey);
      if (meta != null) _totalBytes -= meta.bytes;
      try {
        await File('${_dir!.path}/$lruKey').delete();
      } catch (_) {}
    }
  }

  /// Schedule a debounced index flush (coalesces bursts of writes).
  void _persistIndex() {
    if (!_usable) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _flushIndex);
  }

  void _flushIndex() {
    if (!_usable) return;
    final snapshot = <String, dynamic>{
      for (final e in _index.entries) e.key: e.value.toJson(),
    };
    // Chain writes so they can't interleave.
    _indexWrite = _indexWrite.then((_) async {
      try {
        await File(
          '${_dir!.path}/index.json',
        ).writeAsString(jsonEncode(snapshot), flush: true);
      } catch (_) {}
    });
  }

  /// Wipe everything (called on logout / clearAuth / account-delete). Clears the
  /// dir so the next user can't see the previous user's cached data.
  Future<void> wipe() async {
    await _ready.future;
    // Cancel any pending debounced flush so it can't rewrite index.json after
    // we've cleared the dir.
    _persistTimer?.cancel();
    _persistTimer = null;
    _index.clear();
    _totalBytes = 0;
    final dir = _dir;
    if (dir == null) return;
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (_) {}
  }
}
