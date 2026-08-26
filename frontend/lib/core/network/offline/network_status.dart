import 'dart:async';

import 'package:flutter/foundation.dart';

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

  final Duration _offlineDebounce;

  final Future<bool> Function()? _probe;
  final Duration _firstProbeDelay;
  final Duration _maxProbeDelay;

  bool _online = true;
  Timer? _pendingOffline;
  Timer? _probeTimer;
  Duration _probeDelay = Duration.zero;
  bool _probing = false;

  bool get online => _online;
  bool get offline => !_online;

  void markOnline() {
    _pendingOffline?.cancel();
    _pendingOffline = null;
    _stopProbing();
    if (!_online) {
      _online = true;
      notifyListeners();
    }
  }

  void markOffline() {
    if (!_online || _pendingOffline != null) return;
    _pendingOffline = Timer(_offlineDebounce, () {
      _pendingOffline = null;
      if (_online) {
        _online = false;
        notifyListeners();
        _scheduleProbe(_firstProbeDelay);
      }
    });
  }

  void probeNow() {
    if (_online || _probe == null) return;
    _probeTimer?.cancel();
    _probeDelay = Duration.zero;
    unawaited(_runProbe());
  }

  void _scheduleProbe(Duration delay) {
    if (_probe == null) return;
    _probeTimer?.cancel();
    _probeDelay = delay > _maxProbeDelay ? _maxProbeDelay : delay;
    _probeTimer = Timer(_probeDelay, () => unawaited(_runProbe()));
  }

  Future<void> _runProbe() async {
    if (_probing || _online || _probe == null) return;
    _probing = true;
    try {
      if (await _probe()) {
        markOnline();
        return;
      }
    } catch (_) {
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
