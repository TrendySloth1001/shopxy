import 'package:flutter/material.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart' show AppThemeMode;
import 'package:shopxy/shared/theme/app_palette.dart';

/// A theme is DATA, not code. [AppThemeSpec] bundles every visual axis — colour
/// palette, font, icon style, corner-shape, density and motion — into one
/// descriptor. The controller activates one spec; the token accessors
/// (`AppColors`, `AppTypography`, `AppIcon`, `AppCurves`, and the component
/// `ThemeData`) all resolve against [active]. Adding or changing a theme is a
/// one-entry edit in [specFor] — components never change ("switch the theme
/// file, not the components").
///
/// The palette axis was already file-swappable via [AppPalette.active]; this
/// wraps it and adds the other five axes on the same pattern.

/// Font personality for a theme. Maps to a concrete family in `AppTypography`.
/// (Hindi/Devanagari always overrides to Noto regardless of this choice.)
enum AppFont {
  /// Platform system font — SF Pro on iOS, Roboto on Android (WhatsApp-like).
  system,

  /// Rounded, friendly sans (Nunito) — softer, more playful.
  rounded,

  /// Editorial serif (Lora) — for paper/warm themes.
  serif,
}

/// Icon glyph style. Hugeicons 1.1.7 ships ONLY `strokeRounded`, so [rounded]
/// is the only value that resolves to real glyphs today. The axis is plumbed
/// end-to-end (spec → [AppIcon]) so a second icon pack can be dropped in behind
/// a new value + a resolver map, with no component or call-site changes.
enum AppIconStyle { rounded }

/// Motion feel — the easing curves an animation reaches for. Paired with the
/// existing `AppDurations`. `AppCurves.*` read the active spec's set.
@immutable
class AppMotion {
  const AppMotion({
    required this.standard,
    required this.emphasized,
    required this.decelerate,
    required this.decelerateEmphasized,
  });

  final Curve standard;
  final Curve emphasized;
  final Curve decelerate;
  final Curve decelerateEmphasized;

  /// Gentle, even easing (Material default feel).
  static const AppMotion calm = AppMotion(
    standard: Curves.easeInOut,
    emphasized: Curves.easeInOutCubic,
    decelerate: Curves.easeOut,
    decelerateEmphasized: Curves.easeOutCubic,
  );

  /// Fast-out, crisp — a snappier, more "productive" tempo.
  static const AppMotion snappy = AppMotion(
    standard: Curves.easeOutCubic,
    emphasized: Curves.easeOutExpo,
    decelerate: Curves.easeOutCubic,
    decelerateEmphasized: Curves.easeOutExpo,
  );

  /// A touch of overshoot on prominent moves — playful, without the bounce of
  /// a full elastic curve.
  static const AppMotion springy = AppMotion(
    standard: Curves.easeOutCubic,
    emphasized: Curves.easeOutBack,
    decelerate: Curves.easeOut,
    decelerateEmphasized: Curves.easeOutBack,
  );
}

@immutable
class AppThemeSpec {
  const AppThemeSpec({
    required this.id,
    required this.label,
    required this.palette,
    this.font = AppFont.system,
    this.iconStyle = AppIconStyle.rounded,
    this.radiusScale = 1.0,
    this.density = VisualDensity.standard,
    this.motion = AppMotion.calm,
  });

  final AppThemeMode id;
  final String label;
  final AppPalette palette;
  final AppFont font;
  final AppIconStyle iconStyle;

  /// Multiplies the *finite* component corner radii (cards, inputs, sheets,
  /// dialogs, menus). Pills (radiusFull) stay fully round regardless. 1.0 =
  /// default; <1 sharper, >1 rounder.
  final double radiusScale;

  /// Material [VisualDensity] applied to the whole app — the compact/comfy axis.
  final VisualDensity density;

  final AppMotion motion;

  /// The active theme spec. Swapped by [ThemePrefsProvider] before the tree
  /// rebuilds, alongside [AppPalette.active]. Defaults to light so tokens
  /// resolve correctly before the controller loads.
  static AppThemeSpec active = specFor(AppThemeMode.light);
}

/// The single registry — one entry per theme. THIS is the "theme file" you edit
/// to tune or add a look; nothing downstream changes. Each theme carries its own
/// font / shape / density / motion personality on top of its palette.
AppThemeSpec specFor(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return AppThemeSpec(
        id: mode,
        label: 'Light',
        palette: AppPalette.light,
      );
    case AppThemeMode.beige:
      return AppThemeSpec(
        id: mode,
        label: 'Beige',
        palette: AppPalette.beige,
        font: AppFont.serif,
        radiusScale: 1.15,
        density: VisualDensity.comfortable,
      );
    case AppThemeMode.rose:
      return AppThemeSpec(
        id: mode,
        label: 'Rose',
        palette: AppPalette.rose,
        font: AppFont.rounded,
        radiusScale: 1.3,
        density: VisualDensity.comfortable,
        motion: AppMotion.springy,
      );
    case AppThemeMode.sage:
      return AppThemeSpec(
        id: mode,
        label: 'Sage',
        palette: AppPalette.sage,
        radiusScale: 1.1,
      );
    case AppThemeMode.dark:
      return AppThemeSpec(
        id: mode,
        label: 'Dark',
        palette: AppPalette.dark,
      );
    case AppThemeMode.oled:
      return AppThemeSpec(
        id: mode,
        label: 'OLED',
        palette: AppPalette.oled,
        radiusScale: 0.6,
        density: VisualDensity.compact,
        motion: AppMotion.snappy,
      );
    case AppThemeMode.midnight:
      return AppThemeSpec(
        id: mode,
        label: 'Midnight',
        palette: AppPalette.midnight,
        font: AppFont.rounded,
        radiusScale: 1.2,
      );
    case AppThemeMode.nord:
      return AppThemeSpec(
        id: mode,
        label: 'Nord',
        palette: AppPalette.nord,
        radiusScale: 0.85,
        density: VisualDensity.compact,
        motion: AppMotion.snappy,
      );
  }
}
