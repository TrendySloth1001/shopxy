import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.userId,
    required this.method,
    required this.path,
    required this.body,
    required this.headers,
    required this.createdAtMs,
    this.attempts = 0,
  });

  final String id;
  final String userId;
  final String method;
  final String path;

  final String? body;
  final Map<String, String> headers;
  final int createdAtMs;
  int attempts;

  Map<String, dynamic> toJson() => {
    'id': id,
    'u': userId,
    'm': method,
    'p': path,
    'b': body,
    'h': headers,
    'c': createdAtMs,
    'a': attempts,
  };

  static OutboxEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], u = j['u'], m = j['m'], p = j['p'], c = j['c'];
    if (id is! String || u is! String || m is! String || p is! String) {
      return null;
    }
    return OutboxEntry(
      id: id,
      userId: u,
      method: m,
      path: p,
      body: j['b'] as String?,
      headers: (j['h'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {},
      createdAtMs: c is int ? c : 0,
      attempts: j['a'] is int ? j['a'] as int : 0,
    );
  }
}

class Outbox {
  Outbox({int maxEntries = 500}) : _maxEntries = maxEntries;

  final int _maxEntries;

  Directory? _dir;
  File get _file => File('${_dir!.path}/outbox.json');

  final List<OutboxEntry> _entries = [];
  final Completer<void> _ready = Completer<void>();
  bool _usable = false;
  int _seq = 0;
  Future<void> _write = Future.value();

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  Future<void> init() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/offline_outbox');
      await dir.create(recursive: true);
      _dir = dir;
      await _load();
      _usable = true;
      pendingCount.value = _entries.length;
    } catch (e) {
      _usable = false;
      if (kDebugMode) debugPrint('Outbox: disabled ($e)');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _load() async {
    if (!await _file.exists()) return;
    try {
      final raw = jsonDecode(await _file.readAsString());
      if (raw is! List) return;
      for (final item in raw) {
        final e = OutboxEntry.fromJson(item);
        if (e != null) _entries.add(e);
      }
    } catch (_) {
      _entries.clear();
    }
  }

  String _newId() {
    _seq += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_seq';
  }

  Future<OutboxEntry> enqueue({
    required String userId,
    required String method,
    required String path,
    String? body,
    Map<String, String> headers = const {},
  }) async {
    await _ready.future;
    final entry = OutboxEntry(
      id: _newId(),
      userId: userId,
      method: method,
      path: path,
      body: body,
      headers: headers,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _entries.add(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    pendingCount.value = _entries.length;
    _persist();
    return entry;
  }

  List<OutboxEntry> pending(String userId) =>
      _entries.where((e) => e.userId == userId).toList();

  Future<void> remove(String id) async {
    await _ready.future;
    _entries.removeWhere((e) => e.id == id);
    pendingCount.value = _entries.length;
    _persist();
  }

  Future<int> recordFailure(String id) async {
    await _ready.future;
    final entry = _entries.firstWhere(
      (e) => e.id == id,
      orElse: () => throw StateError('outbox entry $id missing'),
    );
    entry.attempts += 1;
    _persist();
    return entry.attempts;
  }

  Future<void> wipe() async {
    await _ready.future;
    _entries.clear();
    pendingCount.value = 0;
    _persist();
  }

  void _persist() {
    if (!_usable) return;
    final snapshot = jsonEncode([for (final e in _entries) e.toJson()]);
    _write = _write.then((_) async {
      try {
        await _file.writeAsString(snapshot, flush: true);
      } catch (_) {}
    });
  }
}
