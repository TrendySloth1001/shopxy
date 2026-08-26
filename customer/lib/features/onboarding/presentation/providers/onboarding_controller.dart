import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingController extends ChangeNotifier {
  static const _key = 'onboarding_seen_v1';

  bool _seen = false;
  bool _loaded = false;

  bool get seen => _seen;

  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _seen = prefs.getBool(_key) ?? false;
    } catch (_) {
      _seen = false;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> complete() async {
    if (_seen) return;
    _seen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
    }
  }
}
