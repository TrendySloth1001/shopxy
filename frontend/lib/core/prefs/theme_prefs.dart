import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shopxy/shared/theme/app_palette.dart';

enum AppThemeMode { light, beige, rose, sage, dark, oled, midnight, nord }

class ThemePrefsProvider extends ChangeNotifier {
  ThemePrefsProvider(this._storage);

  static const _key = 'app.themeMode';

  final FlutterSecureStorage _storage;
  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;

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
