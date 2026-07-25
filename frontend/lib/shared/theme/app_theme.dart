import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_palette.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_typography.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// Builds the app [ThemeData] from an [AppPalette]. One builder drives all
/// eight themes (light / beige / rose / sage / dark / OLED / midnight / nord) —
/// the palette carries the colour differences, this file carries the shared
/// component styling.
///
/// Component surfaces (cards, inputs, sheets, menus, dialogs) read
/// [AppPalette.surface], text/icons read [AppPalette.ink], the strong neutral
/// CTA (filled/elevated buttons, snackbar, selected chip) uses the
/// [AppPalette.inverseSurface] / [AppPalette.onInverse] pair so it stays
/// high-contrast in every theme.
class AppTheme {
  AppTheme._();

  static ThemeData get light => fromPalette(AppPalette.light);
  static ThemeData get beige => fromPalette(AppPalette.beige);
  static ThemeData get rose => fromPalette(AppPalette.rose);
  static ThemeData get sage => fromPalette(AppPalette.sage);
  static ThemeData get dark => fromPalette(AppPalette.dark);
  static ThemeData get oled => fromPalette(AppPalette.oled);
  static ThemeData get midnight => fromPalette(AppPalette.midnight);
  static ThemeData get nord => fromPalette(AppPalette.nord);

  static ThemeData fromPalette(AppPalette p, {bool devanagari = false}) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.ink,
      onPrimary: p.surface,
      primaryContainer: p.surface,
      onPrimaryContainer: p.ink,
      secondary: p.ink,
      onSecondary: p.surface,
      secondaryContainer: p.surface,
      onSecondaryContainer: p.ink,
      tertiary: p.ink,
      onTertiary: p.surface,
      tertiaryContainer: p.surface,
      onTertiaryContainer: p.ink,
      error: p.error,
      onError: p.onAccent,
      errorContainer: p.errorSoft,
      onErrorContainer: p.error,
      surface: p.canvas,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      outline: p.hairline,
      outlineVariant: p.hairline,
      inverseSurface: p.inverseSurface,
      onInverseSurface: p.onInverse,
      inversePrimary: p.surface,
      shadow: p.shadow,
      scrim: p.scrim,
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppTypography.forInk(p.ink, devanagari: devanagari);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      splashColor: p.ink.withValues(alpha: 0.04),
      highlightColor: p.ink.withValues(alpha: 0.04),
      hoverColor: p.ink.withValues(alpha: 0.04),
      dividerColor: p.hairline,
      iconTheme: IconThemeData(color: p.ink, size: AppSizes.iconMd),
      primaryIconTheme: IconThemeData(color: p.onAccent),
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: p.ink,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: p.ink),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: p.hairline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.ink,
        textColor: p.ink,
        tileColor: p.surface,
        selectedTileColor: p.ink.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.xs,
        ),
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: p.ink,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: p.muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.inverseSurface,
          foregroundColor: p.onInverse,
          disabledBackgroundColor: p.hairline,
          disabledForegroundColor: p.disabled,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xl,
            vertical: AppSizes.md,
          ),
          shape: AppShapes.squircle(AppSizes.radiusFull),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.inverseSurface,
          foregroundColor: p.onInverse,
          disabledBackgroundColor: p.hairline,
          disabledForegroundColor: p.disabled,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xl,
            vertical: AppSizes.md,
          ),
          shape: AppShapes.squircle(AppSizes.radiusFull),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          backgroundColor: p.surface,
          side: BorderSide(color: p.ink, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.xl,
            vertical: AppSizes.md,
          ),
          shape: AppShapes.squircle(
            AppSizes.radiusFull,
            side: BorderSide(color: p.ink, width: 1),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          shape: AppShapes.squircle(AppSizes.radiusFull),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.ink,
          backgroundColor: Colors.transparent,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.inverseSurface,
        foregroundColor: p.onInverse,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        splashColor: p.onInverse.withValues(alpha: 0.1),
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.canvas,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.brand,
        elevation: 0,
        height: 64,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: p.onAccent);
          }
          return IconThemeData(color: p.ink);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelSmall?.semibold;
          if (states.contains(WidgetState.selected)) {
            return base?.copyWith(color: p.brandStrong);
          }
          return base?.copyWith(color: p.muted);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: p.ink),
        border: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: p.hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: p.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: p.ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: p.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
          borderSide: BorderSide(color: p.error, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.onInverse),
        actionTextColor: p.onInverse,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // Full-width dialogs: Material's default insets are 40px per side
        // (narrow, floating-in-the-middle). Pull them in to the app's `lg`
        // content gutter so every dialog spans the screen and lines up with
        // the page content and the floating app bar. AlertDialog leaves
        // insetPadding null by default, so this theme value applies app-wide.
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.xxl,
        ),
        shape: AppShapes.squircle(
          AppSizes.radiusDialog,
          side: BorderSide(color: p.hairline, width: 1),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: p.ink),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        modalBarrierColor: p.scrim,
        elevation: 0,
        modalElevation: 0,
        // Hairline edge keeps the sheet defined now that its fill matches the
        // page background (flat surface == canvas).
        shape: AppShapes.squircleTop(
          AppSizes.bottomSheetRadius,
          side: BorderSide(color: p.hairline, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.inverseSurface,
        secondarySelectedColor: p.inverseSurface,
        disabledColor: p.surface,
        // Readable label in BOTH states. M3 selectable chips (Choice/Filter/
        // Input) use `labelStyle` when UNSELECTED and `secondaryLabelStyle`
        // when SELECTED — and they resolve both as PLAIN TextStyles. A
        // WidgetStateTextStyle here is silently ignored for the label colour,
        // leaving it default-black — invisible on the dark selected fill. So
        // colour each state directly: ink unselected, onInverse when selected.
        labelStyle: (textTheme.labelMedium ?? const TextStyle()).copyWith(
          color: p.ink,
        ),
        secondaryLabelStyle: (textTheme.labelMedium ?? const TextStyle())
            .copyWith(color: p.onInverse),
        side: BorderSide(color: p.ink, width: 1),
        shape: AppShapes.squircle(
          AppSizes.radiusFull,
          side: BorderSide(color: p.ink, width: 1),
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
            if (states.contains(WidgetState.selected)) return p.inverseSurface;
            return p.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return p.onInverse;
            return p.ink;
          }),
          side: WidgetStateProperty.all(BorderSide(color: p.ink, width: 1)),
          textStyle: WidgetStateProperty.all(textTheme.labelMedium),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        circularTrackColor: Colors.transparent,
        linearTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.onInverse;
          return p.ink;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.inverseSurface;
          return p.surface;
        }),
        trackOutlineColor: WidgetStateProperty.all(p.ink),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.inverseSurface;
          return p.surface;
        }),
        checkColor: WidgetStateProperty.all(p.onInverse),
        side: BorderSide(color: p.ink, width: 1.5),
        shape: AppShapes.squircle(AppSizes.radiusSm / 2),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.all(p.ink)),
      tabBarTheme: TabBarThemeData(
        labelColor: p.ink,
        unselectedLabelColor: p.muted,
        indicatorColor: p.ink,
        dividerColor: p.hairline,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: p.inverseSurface,
          shape: AppShapes.squircle(AppSizes.radiusSm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: p.onInverse),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: p.hairline, width: 1),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: p.ink),
      ),
    );
  }
}
