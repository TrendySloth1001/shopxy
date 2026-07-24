import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shopxy/shared/theme/app_palette.dart';

/// The eight themes the merchant app ships, mirroring the web app. Two families
/// — light (dark ink on a light ground) and dark (light ink on a dark ground):
/// - [light]    — warm canvas, dark text (default).
/// - [beige]    — soft sepia paper.
/// - [rose]     — warm blush / rosé.
/// - [sage]     — cool mint-green, calm.
/// - [dark]     — normal dark: deep-slate surfaces.
/// - [oled]     — true black, for OLED panels (shares the dark palette).
/// - [midnight] — deep navy / indigo.
/// - [nord]     — muted arctic blue-grey.
enum AppThemeMode { light, beige, rose, sage, dark, oled, midnight, nord }

/// Owns the selected theme and persists it to the same secure-storage
/// container used for auth tokens / nav prefs (no new dependency). Loaded in
/// `main()` before the first frame so the app opens in the saved theme.
class ThemePrefsProvider extends ChangeNotifier {
  ThemePrefsProvider(this._storage);

  static const _key = 'app.themeMode';

  final FlutterSecureStorage _storage;
  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;

  /// The resolved palette for the current mode.
  AppPalette get palette => paletteFor(_mode);

  static AppPalette paletteFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return AppPalette.light;
      case AppThemeMode.beige:
        return AppPalette.beige;
      case AppThemeMode.rose:
        return AppPalette.rose;
      case AppThemeMode.sage:
        return AppPalette.sage;
      case AppThemeMode.dark:
        return AppPalette.dark;
      case AppThemeMode.oled:
        return AppPalette.oled;
      case AppThemeMode.midnight:
        return AppPalette.midnight;
      case AppThemeMode.nord:
        return AppPalette.nord;
    }
  }

  Future<void> load() async {
    final raw = await _storage.read(key: _key);
    _mode = _parse(raw);
    // Make the active palette correct for the very first build.
    AppPalette.active = palette;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode value) async {
    if (_mode == value) return;
    _mode = value;
    AppPalette.active = palette;
    notifyListeners();
    await _storage.write(key: _key, value: value.name);
  }

  static AppThemeMode _parse(String? raw) {
    switch (raw) {
      case 'beige':
        return AppThemeMode.beige;
      case 'rose':
        return AppThemeMode.rose;
      case 'sage':
        return AppThemeMode.sage;
      case 'dark':
        return AppThemeMode.dark;
      case 'oled':
        return AppThemeMode.oled;
      case 'midnight':
        return AppThemeMode.midnight;
      case 'nord':
        return AppThemeMode.nord;
      default:
        return AppThemeMode.light;
    }
  }
}
