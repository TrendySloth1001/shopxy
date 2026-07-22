import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import 'package:shopxy/core/network/offline/network_status.dart';
import 'package:shopxy/core/network/offline/outbox.dart';

/// Drains the [Outbox] whenever connectivity returns (and once at startup, so
/// entries left from a session that ended offline sync as soon as possible).
///
/// It depends on a [replay] function rather than `ApiClient` directly — the
/// only coupling it needs is "send this entry, give me the response" — which
/// keeps it unit-testable and inverts the dependency.
///
/// Per-entry conflict policy — "the online session wins":
/// - **2xx** → applied; drop the entry.
/// - **4xx** → permanent (validation, or the resource changed on the server,
///   e.g. a web session edited it first). Drop our stale update rather than
///   retrying forever — last-write-wins toward the server.
/// - **5xx** → a per-entry server error. Record a failed attempt and move ON to
///   the next entry (no head-of-line blocking); drop the entry once it has
///   failed [maxAttempts] times so a poison entry can't wedge the queue.
/// - **network error thrown** → connectivity dropped mid-drain; stop and retry
///   the whole queue on the next online signal.
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

  /// Begin watching connectivity + attempt an immediate drain.
  void start() {
    _networkStatus.addListener(_onStatusChanged);
    _maybeDrain();
  }

  /// Kept reachable (and exercised by tests) so an app teardown / a re-created
  /// processor doesn't leak the connectivity listener.
  void dispose() {
    _networkStatus.removeListener(_onStatusChanged);
  }

  void _onStatusChanged() {
    if (_networkStatus.online) _maybeDrain();
  }

  /// Run one drain pass and await it. `start()` fires drains unawaited in
  /// production; tests use this to observe the result deterministically.
  @visibleForTesting
  Future<void> drain() => _maybeDrain();

  Future<void> _maybeDrain() async {
    if (_draining || _networkStatus.offline) return;
    _draining = true;
    try {
      final userId = _currentUserId();
      if (userId == 'anon') return; // not signed in yet — nothing to sync
      for (final entry in _outbox.pending(userId)) {
        final http.Response resp;
        try {
          resp = await _replay(entry);
        } catch (_) {
          break; // network dropped again → retry the whole queue next reconnect
        }
        final code = resp.statusCode;
        if (code >= 200 && code < 400) {
          await _outbox.remove(entry.id); // applied (2xx/3xx)
        } else if (code < 500) {
          await _outbox.remove(entry.id); // 4xx permanent → server wins
        } else {
          // 5xx: transient server error for THIS entry. Count it and continue
          // to the next entry rather than blocking the queue.
          final attempts = await _outbox.recordFailure(entry.id);
          if (attempts >= _maxAttempts) await _outbox.remove(entry.id);
        }
      }
    } finally {
      _draining = false;
    }
  }
}
