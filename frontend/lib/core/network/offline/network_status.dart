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
  NetworkStatus({Duration offlineDebounce = const Duration(seconds: 2)})
    : _offlineDebounce = offlineDebounce;

  /// A single failed request can be a fluke. Wait this long for a *second*
  /// signal (another failure, or the absence of any success) before flipping
  /// the UI to offline, so a lone dropped request doesn't flash the banner.
  final Duration _offlineDebounce;

  bool _online = true;
  Timer? _pendingOffline;

  /// True until proven otherwise. Screens read this to decide whether to show
  /// the offline banner.
  bool get online => _online;
  bool get offline => !_online;

  /// A live request completed (we reached the server). Clears any pending
  /// offline flip and restores online immediately.
  void markOnline() {
    _pendingOffline?.cancel();
    _pendingOffline = null;
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
      }
    });
  }

  @override
  void dispose() {
    _pendingOffline?.cancel();
    super.dispose();
  }
}
