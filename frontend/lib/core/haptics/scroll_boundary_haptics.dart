import 'package:flutter/widgets.dart';
import 'package:shopxy/core/haptics/app_haptics.dart';

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
