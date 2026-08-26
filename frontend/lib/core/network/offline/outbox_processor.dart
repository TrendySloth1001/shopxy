import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import 'package:shopxy/core/network/offline/network_status.dart';
import 'package:shopxy/core/network/offline/outbox.dart';

class OutboxProcessor {
  OutboxProcessor({
    required Outbox outbox,
    required NetworkStatus networkStatus,
    required String Function() currentUserId,
    required Future<http.Response> Function(OutboxEntry entry) replay,
    int maxAttempts = 5,
  }) : _outbox = outbox,
       _networkStatus = networkStatus,
       _currentUserId = currentUserId,
       _replay = replay,
       _maxAttempts = maxAttempts;

  final Outbox _outbox;
  final NetworkStatus _networkStatus;
  final String Function() _currentUserId;
  final Future<http.Response> Function(OutboxEntry entry) _replay;
  final int _maxAttempts;

  bool _draining = false;

  void start() {
    _networkStatus.addListener(_onStatusChanged);
    _maybeDrain();
  }

  void dispose() {
    _networkStatus.removeListener(_onStatusChanged);
  }

  void _onStatusChanged() {
    if (_networkStatus.online) _maybeDrain();
  }

  @visibleForTesting
  Future<void> drain() => _maybeDrain();

  Future<void> _maybeDrain() async {
    if (_draining || _networkStatus.offline) return;
    _draining = true;
    try {
      final userId = _currentUserId();
      if (userId == 'anon') return;
      for (final entry in _outbox.pending(userId)) {
        final http.Response resp;
        try {
          resp = await _replay(entry);
        } catch (_) {
          break;
        }
        final code = resp.statusCode;
        if (code >= 200 && code < 400) {
          await _outbox.remove(entry.id);
        } else if (code < 500) {
          await _outbox.remove(entry.id);
        } else {
          final attempts = await _outbox.recordFailure(entry.id);
          if (attempts >= _maxAttempts) await _outbox.remove(entry.id);
        }
      }
    } finally {
      _draining = false;
    }
  }
}
