import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
    // WhatsApp uses the PLATFORM system font — SF Pro on iOS, Roboto on Android
    // — which reads lighter and calmer than a bundled geometric face (Inter).
    // Use the platform typography for Latin; keep Noto Sans Devanagari for Hindi
    // so it renders instead of tofu (□). Sizes are the Material-3 (2021) scale,
    // identical to before — only the family + weights change.
    final base = devanagari
        ? GoogleFonts.notoSansDevanagariTextTheme()
        : Typography.material2021(platform: defaultTargetPlatform).black;
    // Lighter, WhatsApp-like weights: headings sit at w600 (not w700) and
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
