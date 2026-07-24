import 'package:flutter/animation.dart';
import 'package:shopxy/shared/theme/app_theme_spec.dart';

/// Motion easing curves. Pair with [AppDurations] — every animation should use
/// a named curve here so the app's motion feel stays single-sourced, rather
/// than reaching for a raw `Curves.*` at the call site.
///
/// These are now **theme-reactive**: each entry reads the active theme's
/// [AppMotion] set (see [AppThemeSpec]), so switching to a "snappy" or
/// "springy" theme changes the app's motion feel with zero call-site edits.
/// Safe as getters — there are no `const`-context uses of `AppCurves`.
abstract final class AppCurves {
  AppCurves._();

  /// Standard in/out easing for on-screen changes.
  static Curve get standard => AppThemeSpec.active.motion.standard;

  /// Emphasized standard — larger or more prominent moves.
  static Curve get standardEmphasized => AppThemeSpec.active.motion.emphasized;

  /// Decelerate — elements entering the screen (ease-out).
  static Curve get decelerate => AppThemeSpec.active.motion.decelerate;

  /// Emphasized decelerate — prominent entrances.
  static Curve get decelerateEmphasized =>
      AppThemeSpec.active.motion.decelerateEmphasized;
}
