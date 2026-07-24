import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shopxy/shared/theme/app_palette.dart';
import 'package:shopxy/shared/theme/app_theme_spec.dart';

/// The eight colour palettes the app ships (the COLOUR axis). Two families —
/// light (dark ink on a light ground) and dark (light ink on a dark ground).
enum AppThemeMode { light, beige, rose, sage, dark, oled, midnight, nord }

/// Owns the user's per-axis theme choices — colour, font, corner-shape, density
/// and motion — and composes them into the active [AppThemeSpec]. Choices can be
/// set individually ("Custom") or all at once from a [ThemePreset]. Persists to
/// the same secure-storage container used for auth tokens (no new dependency).
/// Loaded in `main()` before the first frame so the app opens in the saved look.
class ThemePrefsProvider extends ChangeNotifier {
  ThemePrefsProvider(this._storage);

  static const _modeKey = 'app.themeMode'; // colour palette (legacy key kept)
  static const _fontKey = 'app.themeFont';
  static const _iconKey = 'app.themeIcon';
  static const _shapeKey = 'app.themeShape';
  static const _densityKey = 'app.themeDensity';
  static const _motionKey = 'app.themeMotion';

  final FlutterSecureStorage _storage;

  AppThemeMode _mode = AppThemeMode.light;
  AppFont _font = AppFont.system;
  AppIconStyle _iconStyle = AppIconStyle.hugeicons;
  AppShape _shape = AppShape.standard;
  AppDensityChoice _density = AppDensityChoice.standard;
  AppMotionChoice _motion = AppMotionChoice.calm;

  // ── Per-axis getters ──────────────────────────────────────────────────────
  AppThemeMode get mode => _mode;
  AppFont get font => _font;
  AppIconStyle get iconStyle => _iconStyle;
  AppShape get shape => _shape;
  AppDensityChoice get density => _density;
  AppMotionChoice get motion => _motion;

  /// The resolved palette for the current colour choice.
  AppPalette get palette => paletteFor(_mode);

  /// The composed, active theme descriptor read across the app.
  AppThemeSpec get spec => AppThemeSpec(
    palette: palette,
    font: _font,
    iconStyle: _iconStyle,
    radiusScale: _shape.radiusScale,
    density: _density.visualDensity,
    motion: _motion.motion,
  );

  /// The preset whose full config matches the current axes, or null = "Custom".
  ThemePreset? get activePreset {
    for (final p in kThemePresets) {
      if (p.palette == _mode &&
          p.font == _font &&
          p.iconStyle == _iconStyle &&
          p.shape == _shape &&
          p.density == _density &&
          p.motion == _motion) {
        return p;
      }
    }
    return null;
  }

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
    _mode = _parseMode(await _storage.read(key: _modeKey));
    _font = _byName(await _storage.read(key: _fontKey), AppFont.values, AppFont.system);
    _iconStyle = _byName(
      await _storage.read(key: _iconKey),
      AppIconStyle.values,
      AppIconStyle.hugeicons,
    );
    _shape = _byName(await _storage.read(key: _shapeKey), AppShape.values, AppShape.standard);
    _density = _byName(
      await _storage.read(key: _densityKey),
      AppDensityChoice.values,
      AppDensityChoice.standard,
    );
    _motion = _byName(
      await _storage.read(key: _motionKey),
      AppMotionChoice.values,
      AppMotionChoice.calm,
    );
    _activate();
    notifyListeners();
  }

  // ── Per-axis setters ──────────────────────────────────────────────────────
  Future<void> setMode(AppThemeMode value) => _set(_modeKey, value.name, () => _mode = value);
  Future<void> setFont(AppFont value) => _set(_fontKey, value.name, () => _font = value);
  Future<void> setIconStyle(AppIconStyle value) =>
      _set(_iconKey, value.name, () => _iconStyle = value);
  Future<void> setShape(AppShape value) => _set(_shapeKey, value.name, () => _shape = value);
  Future<void> setDensity(AppDensityChoice value) =>
      _set(_densityKey, value.name, () => _density = value);
  Future<void> setMotion(AppMotionChoice value) =>
      _set(_motionKey, value.name, () => _motion = value);

  /// Apply a curated preset — sets every axis at once and persists all.
  Future<void> applyPreset(ThemePreset p) async {
    _mode = p.palette;
    _font = p.font;
    _iconStyle = p.iconStyle;
    _shape = p.shape;
    _density = p.density;
    _motion = p.motion;
    _activate();
    notifyListeners();
    await _storage.write(key: _modeKey, value: p.palette.name);
    await _storage.write(key: _fontKey, value: p.font.name);
    await _storage.write(key: _iconKey, value: p.iconStyle.name);
    await _storage.write(key: _shapeKey, value: p.shape.name);
    await _storage.write(key: _densityKey, value: p.density.name);
    await _storage.write(key: _motionKey, value: p.motion.name);
  }

  Future<void> _set(String key, String value, VoidCallback apply) async {
    apply();
    _activate();
    notifyListeners();
    await _storage.write(key: key, value: value);
  }

  /// Push the composed spec + palette into the global accessors so the very next
  /// build (and every non-reactive `AppColors.*` read) is correct.
  void _activate() {
    AppPalette.active = palette;
    AppThemeSpec.active = spec;
  }

  static AppThemeMode _parseMode(String? raw) {
    for (final m in AppThemeMode.values) {
      if (m.name == raw) return m;
    }
    return AppThemeMode.light;
  }

  static T _byName<T extends Enum>(String? raw, List<T> values, T fallback) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }
}
