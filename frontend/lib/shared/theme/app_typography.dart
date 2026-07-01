import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get light => _build(AppColors.black);
  static TextTheme get dark => _build(AppColors.black);

  /// Build the type scale tinted to a specific ink colour — used by [AppTheme]
  /// so each theme gets text in its own ink. When [devanagari] is true the base
  /// face swaps from Inter (Latin-only) to Noto Sans Devanagari so Hindi and
  /// other Devanagari-script languages actually render instead of showing
  /// tofu (□) boxes.
  static TextTheme forInk(Color ink, {bool devanagari = false}) =>
      _build(ink, devanagari: devanagari);

  static TextTheme _build(Color textColor, {bool devanagari = false}) {
    final base = devanagari
        ? GoogleFonts.notoSansDevanagariTextTheme()
        : GoogleFonts.interTextTheme();
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
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
