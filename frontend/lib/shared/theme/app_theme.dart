import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_typography.dart';

/// Minimal two-tone theme. White background, black ink, single hairline.
/// Light and dark currently resolve to the same look — dark colours will be
/// decided later. Until then both modes look identical to keep the app stable.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _theme();
  static ThemeData get dark => _theme();

  static ThemeData _theme() {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.black,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.white,
      onPrimaryContainer: AppColors.black,
      secondary: AppColors.black,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.white,
      onSecondaryContainer: AppColors.black,
      tertiary: AppColors.black,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.white,
      onTertiaryContainer: AppColors.black,
      error: AppColors.error,
      onError: AppColors.white,
      errorContainer: AppColors.white,
      onErrorContainer: AppColors.error,
      surface: AppColors.canvas,
      onSurface: AppColors.black,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.hairline,
      outlineVariant: AppColors.hairline,
      inverseSurface: AppColors.black,
      onInverseSurface: AppColors.white,
      inversePrimary: AppColors.white,
      shadow: AppColors.black.withValues(alpha: 0.04),
      scrim: AppColors.black.withValues(alpha: 0.4),
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppTypography.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: AppColors.canvas,
      splashColor: AppColors.black.withValues(alpha: 0.04),
      highlightColor: AppColors.black.withValues(alpha: 0.04),
      hoverColor: AppColors.black.withValues(alpha: 0.04),
      dividerColor: AppColors.hairline,
      iconTheme: const IconThemeData(color: AppColors.black, size: AppSizes.iconMd),
      primaryIconTheme: const IconThemeData(color: AppColors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.black,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.black),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.black,
        textColor: AppColors.black,
        tileColor: AppColors.white,
        selectedTileColor: AppColors.black.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.xs,
        ),
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: AppColors.black,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.hairline,
          disabledForegroundColor: AppColors.disabled,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xl,
            vertical: AppSizes.md,
          ),
          shape: AppShapes.squircle(AppSizes.radiusButton),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.hairline,
          disabledForegroundColor: AppColors.disabled,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xl,
            vertical: AppSizes.md,
          ),
          shape: AppShapes.squircle(AppSizes.radiusButton),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.black, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xl,
            vertical: AppSizes.md,
          ),
          shape: AppShapes.squircle(
            AppSizes.radiusButton,
            side: const BorderSide(color: AppColors.black, width: 1),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.black,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          shape: AppShapes.squircle(AppSizes.radiusButton),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.black,
          backgroundColor: Colors.transparent,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        splashColor: AppColors.white.withValues(alpha: 0.1),
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brand,
        elevation: 0,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.white);
          }
          return const IconThemeData(color: AppColors.black);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          );
          if (states.contains(WidgetState.selected)) {
            return base?.copyWith(color: AppColors.brandStrong);
          }
          return base?.copyWith(color: AppColors.muted);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.black),
        border: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: AppColors.hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: AppColors.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: const BorderSide(color: AppColors.black, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.black,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.white),
        actionTextColor: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: AppShapes.squircle(
          AppSizes.radiusDialog,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: AppColors.black),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.black),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.white,
        modalBarrierColor: AppColors.black.withValues(alpha: 0.4),
        elevation: 0,
        modalElevation: 0,
        shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.black,
        secondarySelectedColor: AppColors.black,
        disabledColor: AppColors.white,
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.black),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: AppColors.white),
        side: const BorderSide(color: AppColors.black, width: 1),
        shape: AppShapes.squircle(
          AppSizes.radiusFull,
          side: const BorderSide(color: AppColors.black, width: 1),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.xs,
        ),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.black;
            return AppColors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.white;
            return AppColors.black;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.black, width: 1),
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelMedium),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        // Brand-green progress matches the Glassdoor segmented progress bar.
        color: AppColors.brand,
        circularTrackColor: Colors.transparent,
        linearTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return AppColors.black;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.black;
          return AppColors.white;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColors.black),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.black;
          return AppColors.white;
        }),
        checkColor: WidgetStateProperty.all(AppColors.white),
        side: const BorderSide(color: AppColors.black, width: 1.5),
        shape: AppShapes.squircle(AppSizes.radiusSm / 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(AppColors.black),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.black,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.black,
        dividerColor: AppColors.hairline,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: AppColors.black,
          shape: AppShapes.squircle(AppSizes.radiusSm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: AppColors.white),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: AppColors.black),
      ),
    );
  }
}
