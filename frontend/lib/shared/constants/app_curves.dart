import 'package:flutter/animation.dart';

/// Motion easing curves. Pair with [AppDurations] — every animation should use
/// a named curve here so the app's motion feel stays single-sourced, rather
/// than reaching for a raw `Curves.*` at the call site.
abstract final class AppCurves {
  AppCurves._();

  /// Standard in/out easing for on-screen changes.
  static const Curve standard = Curves.easeInOut;

  /// Emphasized standard (cubic) — larger or more prominent moves.
  static const Curve standardEmphasized = Curves.easeInOutCubic;

  /// Decelerate — elements entering the screen (ease-out).
  static const Curve decelerate = Curves.easeOut;

  /// Emphasized decelerate (cubic) — prominent entrances.
  static const Curve decelerateEmphasized = Curves.easeOutCubic;
}
