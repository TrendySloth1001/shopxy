import 'package:flutter/services.dart';
import 'package:shopxy/core/haptics/haptics_prefs.dart';

abstract final class AppHaptics {
  static HapticsPrefsProvider? _prefs;

  static void attach(HapticsPrefsProvider prefs) => _prefs = prefs;

  static bool get _enabled => _prefs?.enabled ?? true;

  static void selection() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }
}
