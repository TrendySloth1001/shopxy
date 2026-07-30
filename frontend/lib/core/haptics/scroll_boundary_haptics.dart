import 'package:flutter/widgets.dart';
import 'package:shopxy/core/haptics/app_haptics.dart';

/// Fires a light haptic tick the moment a scrollable reaches its top or
/// bottom edge — the same subtle "arrived" cue as a native bounce-back.
///
/// Attach once per [ScrollController] in `initState`, alongside any existing
/// listener the page already has (pagination, sticky-header threshold, etc.)
/// — this adds its own listener rather than replacing one. Call [dispose]
/// in the page's `dispose` before disposing the controller itself.
class ScrollBoundaryHaptics {
  ScrollBoundaryHaptics(this._controller) {
    _controller.addListener(_onScroll);
  }

  final ScrollController _controller;
  bool _atTop = false;
  bool _atBottom = false;

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final atTop = position.pixels <= position.minScrollExtent;
    final atBottom = position.pixels >= position.maxScrollExtent;
    if (atTop && !_atTop) AppHaptics.light();
    if (atBottom && !_atBottom) AppHaptics.light();
    _atTop = atTop;
    _atBottom = atBottom;
  }

  void dispose() => _controller.removeListener(_onScroll);
}
