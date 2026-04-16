import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme get light => _build(const Color(0xFF000000));
  static TextTheme get dark => _build(const Color(0xFFF5F0E8));

  static TextTheme _build(Color textColor) {
    final base = GoogleFonts.spaceGroteskTextTheme();
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
          displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700),
          displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w600),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.4),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: textColor, displayColor: textColor);
  }
}
