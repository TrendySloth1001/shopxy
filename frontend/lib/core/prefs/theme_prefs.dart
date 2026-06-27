import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shopxy/shared/theme/app_palette.dart';

/// The three themes the merchant app ships, mirroring the web app:
/// - [light] — warm canvas, dark text (default).
/// - [dark]  — normal dark: deep-slate surfaces.
/// - [oled]  — true black, for OLED panels (shares the dark palette).
enum AppThemeMode { light, dark, oled }

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
      case AppThemeMode.dark:
        return AppPalette.dark;
      case AppThemeMode.oled:
        return AppPalette.oled;
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
      case 'dark':
        return AppThemeMode.dark;
      case 'oled':
        return AppThemeMode.oled;
      default:
        return AppThemeMode.light;
    }
  }
}
