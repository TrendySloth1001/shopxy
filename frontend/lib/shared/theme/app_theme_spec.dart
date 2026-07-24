import 'package:flutter/material.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart' show AppThemeMode;
import 'package:shopxy/shared/theme/app_palette.dart';

/// A theme is DATA composed from independent AXES — colour, font, corner-shape,
/// density and motion — each chosen separately. [AppThemeSpec] is the RESOLVED
/// bundle the app reads; the controller ([ThemePrefsProvider]) composes it from
/// the user's per-axis choices (or from a [ThemePreset]). Every token accessor
/// (`AppColors`, `AppTypography`, `AppIcon`, `AppCurves`, the component
/// `ThemeData`) resolves against [AppThemeSpec.active] — so changing any axis
/// re-themes the whole app with zero component edits.

// ── Axis: font ────────────────────────────────────────────────────────────────
/// Font personality. Maps to a concrete family in `AppTypography`. (Hindi always
/// overrides to Noto regardless.)
enum AppFont {
  system('System'),
  rounded('Rounded'),
  serif('Serif');

  const AppFont(this.label);
  final String label;
}

// ── Axis: icon style ──────────────────────────────────────────────────────────
/// Icon glyph style. Hugeicons 1.1.7 ships ONLY `strokeRounded`, so [rounded] is
/// the only value that resolves to real glyphs today; the axis is plumbed
/// (spec → `AppIcon`) so a second pack drops in behind a new value.
enum AppIconStyle {
  rounded('Rounded');

  const AppIconStyle(this.label);
  final String label;
}

// ── Axis: corner shape ────────────────────────────────────────────────────────
/// Corner-shape feel — scales the finite component radii (pills stay round).
enum AppShape {
  sharp('Sharp', 0.5),
  standard('Default', 1.0),
  round('Round', 1.5);

  const AppShape(this.label, this.radiusScale);
  final String label;
  final double radiusScale;
}

// ── Axis: density ─────────────────────────────────────────────────────────────
/// Compact / comfy — Material [VisualDensity] applied app-wide.
enum AppDensityChoice {
  compact('Compact', VisualDensity.compact),
  standard('Standard', VisualDensity.standard),
  comfortable('Comfortable', VisualDensity.comfortable);

  const AppDensityChoice(this.label, this.visualDensity);
  final String label;
  final VisualDensity visualDensity;
}

// ── Axis: motion ──────────────────────────────────────────────────────────────
/// The easing set an animation reaches for (via theme-reactive `AppCurves`).
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

  static const AppMotion calm = AppMotion(
    standard: Curves.easeInOut,
    emphasized: Curves.easeInOutCubic,
    decelerate: Curves.easeOut,
    decelerateEmphasized: Curves.easeOutCubic,
  );
  static const AppMotion snappy = AppMotion(
    standard: Curves.easeOutCubic,
    emphasized: Curves.easeOutExpo,
    decelerate: Curves.easeOutCubic,
    decelerateEmphasized: Curves.easeOutExpo,
  );
  static const AppMotion springy = AppMotion(
    standard: Curves.easeOutCubic,
    emphasized: Curves.easeOutBack,
    decelerate: Curves.easeOut,
    decelerateEmphasized: Curves.easeOutBack,
  );
}

enum AppMotionChoice {
  calm('Calm', AppMotion.calm),
  snappy('Snappy', AppMotion.snappy),
  springy('Springy', AppMotion.springy);

  const AppMotionChoice(this.label, this.motion);
  final String label;
  final AppMotion motion;
}

/// Human label for a colour palette (the colour axis' options).
String paletteLabel(AppThemeMode mode) => switch (mode) {
  AppThemeMode.light => 'Light',
  AppThemeMode.beige => 'Beige',
  AppThemeMode.rose => 'Rose',
  AppThemeMode.sage => 'Sage',
  AppThemeMode.dark => 'Dark',
  AppThemeMode.oled => 'OLED',
  AppThemeMode.midnight => 'Midnight',
  AppThemeMode.nord => 'Nord',
};

// ── The resolved, active spec ─────────────────────────────────────────────────
@immutable
class AppThemeSpec {
  const AppThemeSpec({
    required this.palette,
    this.font = AppFont.system,
    this.iconStyle = AppIconStyle.rounded,
    this.radiusScale = 1.0,
    this.density = VisualDensity.standard,
    this.motion = AppMotion.calm,
  });

  final AppPalette palette;
  final AppFont font;
  final AppIconStyle iconStyle;

  /// Multiplies the finite component corner radii. Pills stay round.
  final double radiusScale;
  final VisualDensity density;
  final AppMotion motion;

  /// The active theme spec — swapped by [ThemePrefsProvider] before the tree
  /// rebuilds, alongside [AppPalette.active].
  static AppThemeSpec active = const AppThemeSpec(palette: AppPalette.light);
}

// ── Presets — curated, ready-made configs ("our own made configs") ────────────
/// A named full config across every axis. Selecting one sets all axes at once;
/// changing any axis afterwards drops the selection to "Custom".
@immutable
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.label,
    required this.palette,
    this.font = AppFont.system,
    this.shape = AppShape.standard,
    this.density = AppDensityChoice.standard,
    this.motion = AppMotionChoice.calm,
  });

  final String id;
  final String label;
  final AppThemeMode palette;
  final AppFont font;
  final AppShape shape;
  final AppDensityChoice density;
  final AppMotionChoice motion;
}

/// The predefined configs. Edit / add here — nothing downstream changes.
const List<ThemePreset> kThemePresets = [
  ThemePreset(id: 'whatsapp', label: 'WhatsApp', palette: AppThemeMode.light),
  ThemePreset(
    id: 'whatsapp_dark',
    label: 'WhatsApp Dark',
    palette: AppThemeMode.dark,
  ),
  ThemePreset(
    id: 'playful',
    label: 'Playful',
    palette: AppThemeMode.rose,
    font: AppFont.rounded,
    shape: AppShape.round,
    density: AppDensityChoice.comfortable,
    motion: AppMotionChoice.springy,
  ),
  ThemePreset(
    id: 'sharp',
    label: 'Sharp',
    palette: AppThemeMode.oled,
    shape: AppShape.sharp,
    density: AppDensityChoice.compact,
    motion: AppMotionChoice.snappy,
  ),
  ThemePreset(
    id: 'paper',
    label: 'Paper',
    palette: AppThemeMode.beige,
    font: AppFont.serif,
    shape: AppShape.round,
    density: AppDensityChoice.comfortable,
  ),
  ThemePreset(
    id: 'nordic',
    label: 'Nordic',
    palette: AppThemeMode.nord,
    density: AppDensityChoice.compact,
    motion: AppMotionChoice.snappy,
  ),
  ThemePreset(
    id: 'sage',
    label: 'Sage',
    palette: AppThemeMode.sage,
    shape: AppShape.round,
  ),
  ThemePreset(
    id: 'midnight',
    label: 'Midnight',
    palette: AppThemeMode.midnight,
    font: AppFont.rounded,
    shape: AppShape.round,
  ),
];
