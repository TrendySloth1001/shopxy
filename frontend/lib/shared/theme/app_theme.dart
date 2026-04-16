import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_typography.dart';

class AppTheme {
  AppTheme._();

  // ── Light ─────────────────────────────────────────
  static ThemeData get light {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.espresso,
      onPrimary: AppColors.paper,
      primaryContainer: AppColors.stone.withValues(alpha: 0.4),
      onPrimaryContainer: AppColors.espresso,
      secondary: AppColors.espresso,
      onSecondary: AppColors.paper,
      secondaryContainer: AppColors.stone.withValues(alpha: 0.3),
      onSecondaryContainer: AppColors.espresso,
      tertiary: AppColors.espresso,
      onTertiary: AppColors.paper,
      tertiaryContainer: AppColors.stone.withValues(alpha: 0.3),
      onTertiaryContainer: AppColors.espresso,
      error: AppColors.error,
      onError: AppColors.paper,
      errorContainer: AppColors.error.withValues(alpha: 0.12),
      onErrorContainer: AppColors.error,
      surface: AppColors.lightSurface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.lightMuted,
      outline: AppColors.stone,
      outlineVariant: AppColors.stone.withValues(alpha: 0.5),
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paper,
      inversePrimary: AppColors.stone,
      shadow: AppColors.ink.withValues(alpha: 0.08),
      scrim: AppColors.ink.withValues(alpha: 0.3),
      surfaceTint: AppColors.espresso,
    );

    return _buildTheme(
      scheme: scheme,
      textTheme: AppTypography.light,
      scaffoldBg: AppColors.lightBackground,
      appBarBg: AppColors.lightBackground,
      appBarFg: AppColors.ink,
      cardColor: AppColors.paper,
      cardBorder: AppColors.stone.withValues(alpha: 0.6),
      dividerColor: AppColors.stone.withValues(alpha: 0.5),
      inputFill: AppColors.lightSurface,
      inputBorder: AppColors.stone,
      inputFocusBorder: AppColors.espresso,
      fabBg: AppColors.espresso,
      fabFg: AppColors.paper,
      elevatedBtnBg: AppColors.espresso,
      elevatedBtnFg: AppColors.paper,
      navIndicator: AppColors.stone.withValues(alpha: 0.5),
    );
  }

  // ── Dark (OLED) ───────────────────────────────────
  static ThemeData get dark {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.stone,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.espresso.withValues(alpha: 0.6),
      onPrimaryContainer: AppColors.paper,
      secondary: AppColors.stone,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.espresso.withValues(alpha: 0.4),
      onSecondaryContainer: AppColors.paper,
      tertiary: AppColors.stone,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.espresso.withValues(alpha: 0.4),
      onTertiaryContainer: AppColors.paper,
      error: AppColors.error,
      onError: AppColors.paper,
      errorContainer: AppColors.error.withValues(alpha: 0.2),
      onErrorContainer: AppColors.paper,
      surface: AppColors.darkSurface,
      onSurface: AppColors.paper,
      onSurfaceVariant: AppColors.darkMuted,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutline.withValues(alpha: 0.5),
      inverseSurface: AppColors.paper,
      onInverseSurface: AppColors.ink,
      inversePrimary: AppColors.espresso,
      shadow: AppColors.ink,
      scrim: AppColors.ink.withValues(alpha: 0.6),
      surfaceTint: AppColors.stone,
    );

    return _buildTheme(
      scheme: scheme,
      textTheme: AppTypography.dark,
      scaffoldBg: AppColors.darkBackground,
      appBarBg: AppColors.darkBackground,
      appBarFg: AppColors.paper,
      cardColor: AppColors.darkSurface,
      cardBorder: AppColors.darkOutline,
      dividerColor: AppColors.darkOutline,
      inputFill: AppColors.darkSurface,
      inputBorder: AppColors.darkOutline,
      inputFocusBorder: AppColors.stone,
      fabBg: AppColors.paper,
      fabFg: AppColors.ink,
      elevatedBtnBg: AppColors.paper,
      elevatedBtnFg: AppColors.ink,
      navIndicator: AppColors.darkOutline,
    );
  }

  // ── Shared builder ────────────────────────────────
  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required Color scaffoldBg,
    required Color appBarBg,
    required Color appBarFg,
    required Color cardColor,
    required Color cardBorder,
    required Color dividerColor,
    required Color inputFill,
    required Color inputBorder,
    required Color inputFocusBorder,
    required Color fabBg,
    required Color fabFg,
    required Color elevatedBtnBg,
    required Color elevatedBtnFg,
    required Color navIndicator,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: cardBorder),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: elevatedBtnBg,
          foregroundColor: elevatedBtnFg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: AppShapes.squircle(AppSizes.radiusButton),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: AppShapes.squircle(
            AppSizes.radiusButton,
            side: BorderSide(color: scheme.outline),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fabBg,
        foregroundColor: fabFg,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBg,
        indicatorColor: navIndicator,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: inputFocusBorder, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: AppShapes.squircle(AppSizes.radiusMd),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: AppShapes.squircle(AppSizes.radiusDialog),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return scheme.primary;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return scheme.onPrimary;
            return scheme.onSurface;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        ),
      ),
    );
  }
}
