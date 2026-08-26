import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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

class _Meta {
  _Meta({
    required this.userId,
    required this.tag,
    required this.statusCode,
    required this.storedAt,
    required this.bytes,
  });

  final String userId;

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

class HttpCache {
  HttpCache({int maxEntries = 600, int maxBytes = 12 * 1024 * 1024})
    : _maxEntries = maxEntries,
      _maxBytes = maxBytes;

  final int _maxEntries;
  final int _maxBytes;

  Directory? _dir;
  final LinkedHashMap<String, _Meta> _index = LinkedHashMap();
  int _totalBytes = 0;

  final Completer<void> _ready = Completer<void>();
  bool _usable = false;
  Future<void> _indexWrite = Future.value();
  Timer? _persistTimer;
  static const Duration _persistDebounce = Duration(milliseconds: 500);

  Future<void> init() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/http_cache');
      await dir.create(recursive: true);
      _dir = dir;
      await _loadIndex();
      _usable = true;
    } catch (e) {
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
      _index.clear();
      _totalBytes = 0;
    }
  }

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
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xFFFFFFFFFFFFFFFF;
    for (final unit in s.codeUnits) {
      hash = (hash ^ unit) & mask;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Future<CachedResponse?> read(String key) async {
    await _ready.future;
    if (!_usable) return null;
    final meta = _index[key];
    if (meta == null) return null;
    _index.remove(key);
    _index[key] = meta;
    try {
      final body = await File('${_dir!.path}/$key').readAsString();
      if (!identical(_index[key], meta)) return null;
      return CachedResponse(
        body: body,
        statusCode: meta.statusCode,
        storedAt: meta.storedAt,
      );
    } catch (_) {
      if (identical(_index[key], meta)) {
        _index.remove(key);
        _totalBytes -= meta.bytes;
      }
      return null;
    }
  }

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
    }
  }

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
    _indexWrite = _indexWrite.then((_) async {
      try {
        await File(
          '${_dir!.path}/index.json',
        ).writeAsString(jsonEncode(snapshot), flush: true);
      } catch (_) {}
    });
  }

  Future<void> wipe() async {
    await _ready.future;
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
