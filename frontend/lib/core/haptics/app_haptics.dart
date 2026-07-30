import 'package:flutter/services.dart';
import 'package:shopxy/core/haptics/haptics_prefs.dart';

/// Single source of truth for firing haptic feedback app-wide. Every tap
/// site calls one of these instead of `HapticFeedback` directly, so the
/// Settings toggle (backed by [HapticsPrefsProvider]) governs the whole app
/// from one place — flip it off and every call site here goes silent.
abstract final class AppHaptics {
  static HapticsPrefsProvider? _prefs;

  /// Wired once in `main()`, right after [HapticsPrefsProvider] loads.
  static void attach(HapticsPrefsProvider prefs) => _prefs = prefs;

  static bool get _enabled => _prefs?.enabled ?? true;

  /// A discrete choice was made: bottom-nav tab switch, menu-row tap.
  ///
  /// Deliberately `mediumImpact`, not `selectionClick` — the latter is one of
  /// the weakest haptic types on both iOS and Android and is often too subtle
  /// to notice through a case, which made every tap site using it read as
  /// "haptics don't work" even though the call was firing correctly.
  static void selection() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  /// A light tactile tick: a scroll view arriving at its top or bottom edge.
  static void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }
}
