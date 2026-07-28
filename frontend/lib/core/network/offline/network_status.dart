import 'dart:async';

import 'package:flutter/foundation.dart';

/// Single source of truth for connectivity, derived purely from request
/// outcomes — no OS/connectivity package needed (matches the plan's "no new
/// dependency" constraint).
///
/// `ApiClient` reports the result of every live network call:
/// - a completed request (any HTTP status) proves we reached the server →
///   [markOnline].
/// - a socket/timeout failure on the actual call proves the network is down →
///   [markOffline].
///
/// The two directions are deliberately asymmetric:
/// - **→ offline is debounced.** A single dropped request can be a fluke, so we
///   wait [_offlineDebounce] for corroboration before showing the banner. If a
///   success arrives first, the pending flip is cancelled.
/// - **→ online is immediate.** The moment any request succeeds we're clearly
///   back, so the banner clears at once.
class NetworkStatus extends ChangeNotifier {
  NetworkStatus({
    Duration offlineDebounce = const Duration(seconds: 2),
    Future<bool> Function()? probe,
    Duration firstProbeDelay = const Duration(seconds: 2),
    Duration maxProbeDelay = const Duration(seconds: 30),
  }) : _offlineDebounce = offlineDebounce,
       _probe = probe,
       _firstProbeDelay = firstProbeDelay,
       _maxProbeDelay = maxProbeDelay;

  /// A single failed request can be a fluke. Wait this long for a *second*
  /// signal (another failure, or the absence of any success) before flipping
  /// the UI to offline, so a lone dropped request doesn't flash the banner.
  final Duration _offlineDebounce;

  /// Reachability check used to *recover* from offline. Returns true when the
  /// server answered at all — any HTTP status counts, including 503, because
  /// this asks "can we reach the network", not "is the server healthy".
  ///
  /// Injected rather than imported so this class keeps no HTTP dependency and
  /// stays unit-testable without a socket.
  ///
  /// Without it, offline is a **trap**. Every call to [markOnline] originates
  /// from a completed request, and nothing issues a request while offline: the
  /// outbox processor refuses to drain (`if (_networkStatus.offline) return`)
  /// and screens serve cache. So the app waits for a request that waits for the
  /// app — and stays offline after the network is long back, until the merchant
  /// happens to pull-to-refresh. That is the bug this closes.
  final Future<bool> Function()? _probe;
  final Duration _firstProbeDelay;
  final Duration _maxProbeDelay;

  bool _online = true;
  Timer? _pendingOffline;
  Timer? _probeTimer;
  Duration _probeDelay = Duration.zero;
  bool _probing = false;

  /// True until proven otherwise. Screens read this to decide whether to show
  /// the offline banner.
  bool get online => _online;
  bool get offline => !_online;

  /// A live request completed (we reached the server). Clears any pending
  /// offline flip and restores online immediately.
  void markOnline() {
    _pendingOffline?.cancel();
    _pendingOffline = null;
    _stopProbing();
    if (!_online) {
      _online = true;
      notifyListeners();
    }
  }

  /// A live request failed at the transport layer (no server reached). We don't
  /// flip instantly — a single dropped request shouldn't show the banner — we
  /// arm a short timer; if nothing marks us online first, we commit to offline.
  void markOffline() {
    if (!_online || _pendingOffline != null) return;
    _pendingOffline = Timer(_offlineDebounce, () {
      _pendingOffline = null;
      if (_online) {
        _online = false;
        notifyListeners();
        // Nothing else will ever ask again — start asking ourselves.
        _scheduleProbe(_firstProbeDelay);
      }
    });
  }

  /// Ask immediately rather than waiting out the backoff.
  ///
  /// Worth calling when something external suggests the answer just changed —
  /// the app returning to the foreground, or the merchant tapping "retry".
  /// After a phone has been asleep the backoff is already at its ceiling, and
  /// making someone stare at a stale banner for 30s when they've just opened
  /// the app is the visible half of this bug.
  void probeNow() {
    if (_online || _probe == null) return;
    _probeTimer?.cancel();
    _probeDelay = Duration.zero;
    unawaited(_runProbe());
  }

  /// Exponential backoff: quick enough that a brief tunnel or lift recovers in
  /// seconds, slow enough that a genuinely dead network isn't a battery drain.
  void _scheduleProbe(Duration delay) {
    if (_probe == null) return;
    _probeTimer?.cancel();
    _probeDelay = delay > _maxProbeDelay ? _maxProbeDelay : delay;
    _probeTimer = Timer(_probeDelay, () => unawaited(_runProbe()));
  }

  Future<void> _runProbe() async {
    // Re-entrancy guard: [probeNow] can land on top of a scheduled tick, and
    // two in-flight probes would double the backoff progression.
    if (_probing || _online || _probe == null) return;
    _probing = true;
    try {
      if (await _probe()) {
        markOnline();
        return;
      }
    } catch (_) {
      // Still unreachable. Falling through to reschedule is the whole point —
      // a probe that gave up on its own exception would restore the deadlock.
    } finally {
      _probing = false;
    }
    if (!_online) {
      final next = _probeDelay == Duration.zero
          ? _firstProbeDelay
          : _probeDelay * 2;
      _scheduleProbe(next);
    }
  }

  void _stopProbing() {
    _probeTimer?.cancel();
    _probeTimer = null;
    _probeDelay = Duration.zero;
  }

  @override
  void dispose() {
    _pendingOffline?.cancel();
    _stopProbing();
    super.dispose();
  }
}
