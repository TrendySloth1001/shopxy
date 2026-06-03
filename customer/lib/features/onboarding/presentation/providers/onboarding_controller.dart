import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the first-run onboarding has been seen. Persisted to
/// [SharedPreferences] so the carousel shows exactly once per install
/// (bump [_key] if the onboarding content changes enough to re-show).
///
/// Loaded at boot in main.dart; the root view waits on [loaded] before
/// deciding between onboarding and the app shell so there's no flash.
class OnboardingController extends ChangeNotifier {
  static const _key = 'onboarding_seen_v1';

  bool _seen = false;
  bool _loaded = false;

  /// True once onboarding has been completed (or skipped) at least once.
  bool get seen => _seen;

  /// True once the persisted flag has been read — gates the root view so
  /// it doesn't flash onboarding before we know the real value.
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen = prefs.getBool(_key) ?? false;
    } catch (_) {
      // Storage unavailable — treat as not seen; worst case the user
      // sees onboarding again, which is harmless.
      _seen = false;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Mark onboarding done. Flips state immediately (so the UI swaps to
  /// the shell without waiting on disk) then persists best-effort.
  Future<void> complete() async {
    if (_seen) return;
    _seen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      /* best-effort — in-memory flag already flipped for this session */
    }
  }
}
