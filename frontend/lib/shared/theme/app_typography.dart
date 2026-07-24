import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_theme_spec.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get light => _build(AppColors.black);
  static TextTheme get dark => _build(AppColors.black);

  /// Build the type scale tinted to a specific ink colour — used by [AppTheme]
  /// so each theme gets text in its own ink and its own [font]. When
  /// [devanagari] is true the base face swaps to Noto Sans Devanagari so Hindi
  /// renders instead of tofu (□) — that overrides the theme's [font] choice.
  static TextTheme forInk(
    Color ink, {
    bool devanagari = false,
    AppFont font = AppFont.system,
  }) => _build(ink, devanagari: devanagari, font: font);

  /// A single [TextStyle] in [font] — lets a preview render a font choice
  /// without building (and activating) a whole theme.
  static TextStyle sampleStyle(
    AppFont font, {
    Color? color,
    double fontSize = 15,
    FontWeight weight = FontWeight.w600,
  }) {
    final base = _baseFor(font).titleMedium ?? const TextStyle();
    return base.copyWith(color: color, fontSize: fontSize, fontWeight: weight);
  }

  /// Resolve the base (un-tinted) type scale for a font choice.
  static TextTheme _baseFor(AppFont font) {
    switch (font) {
      case AppFont.inter:
        return GoogleFonts.interTextTheme();
      case AppFont.rounded:
        return GoogleFonts.nunitoTextTheme();
      case AppFont.grotesk:
        return GoogleFonts.spaceGroteskTextTheme();
      case AppFont.dmSans:
        return GoogleFonts.dmSansTextTheme();
      case AppFont.jakarta:
        return GoogleFonts.plusJakartaSansTextTheme();
      case AppFont.outfit:
        return GoogleFonts.outfitTextTheme();
      case AppFont.serif:
        return GoogleFonts.loraTextTheme();
      case AppFont.slab:
        return GoogleFonts.robotoSlabTextTheme();
      case AppFont.mono:
        return GoogleFonts.jetBrainsMonoTextTheme();
      case AppFont.system:
        // Platform system font — SF Pro on iOS, Roboto on Android.
        return Typography.material2021(platform: defaultTargetPlatform).black;
    }
  }

  static TextTheme _build(
    Color textColor, {
    bool devanagari = false,
    AppFont font = AppFont.system,
  }) {
    // Latin text uses the theme's chosen font; Hindi keeps Noto Sans Devanagari
    // so it renders instead of tofu (□). Sizes are the Material-3 (2021) scale;
    // only the family + weights change.
    final base =
        devanagari ? GoogleFonts.notoSansDevanagariTextTheme() : _baseFor(font);
    // Lighter, Lighter weights: headings sit at w600 (not w700) and
    // tracking is near-0 because the system faces are already optically spaced —
    // Inter's tight negative tracking made large text feel dense. Explicit
    // emphasis (.bold/.extraBold) at call sites is unaffected.
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
          bodySmall: base.bodySmall?.copyWith(height: 1.4),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: textColor, displayColor: textColor);
  }
}
