import 'package:flutter/material.dart';

/// Resolved colour palette for one theme (light / dark / OLED).
///
/// This is the Flutter analogue of the web app's CSS colour tokens. Because
/// Flutter `Color`s are compile-time constants baked into widgets, we can't
/// cascade a variable the way CSS does — instead the *active* palette is held
/// in [AppPalette.active] and swapped by the theme controller before the app
/// rebuilds. `AppColors.*` are getters that read this active palette, so the
/// existing ~1.8k call sites re-tint automatically when the theme changes.
///
/// Token roles (the important distinctions for theming):
///   • [surface]        — raised card / input / sheet fill. White in light,
///                        a step above the canvas in dark. NOT the same as…
///   • [onAccent]       — literal white foreground for text/icons sitting on a
///                        coloured fill (brand button, FAB). White in every
///                        theme. (`AppColors.white` maps here.)
///   • [ink]            — primary text/icon colour. Flips light on dark.
///                        (`AppColors.black` maps here.)
///   • [inverseSurface] — high-contrast neutral *fill* (avatar, selected chip):
///                        dark in light mode, light in dark mode.
///   • [scrim]          — modal/drawer barrier. Near-black in every theme.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.ink,
    required this.muted,
    required this.subtle,
    required this.disabled,
    required this.hairline,
    required this.surfaceTint,
    required this.canvas,
    required this.pageTint,
    required this.heroPanel,
    required this.surface,
    required this.onAccent,
    required this.inverseSurface,
    required this.onInverse,
    required this.scrim,
    required this.shadow,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.error,
    required this.errorSoft,
    required this.info,
    required this.infoSoft,
    required this.accentTeal,
    required this.accentTealSoft,
    required this.accentIndigo,
    required this.accentIndigoSoft,
    required this.accentAmber,
    required this.accentAmberSoft,
    required this.accentRose,
    required this.accentRoseSoft,
    required this.flashDeal,
    required this.flashDealSoft,
    required this.flashDealSoftAlt,
    required this.whatsapp,
  });

  final Brightness brightness;

  // Inks
  final Color ink;
  final Color muted;
  final Color subtle;
  final Color disabled;
  final Color hairline;
  final Color surfaceTint;

  // Surfaces
  final Color canvas;
  final Color pageTint;
  final Color heroPanel;
  final Color surface;

  // Inverse / literal
  final Color onAccent;
  final Color inverseSurface;
  final Color onInverse;
  final Color scrim;
  final Color shadow;

  // Brand
  final Color brand;
  final Color brandStrong;
  final Color brandSoft;

  // Status
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color error;
  final Color errorSoft;
  final Color info;
  final Color infoSoft;

  // Editorial accents
  final Color accentTeal;
  final Color accentTealSoft;
  final Color accentIndigo;
  final Color accentIndigoSoft;
  final Color accentAmber;
  final Color accentAmberSoft;
  final Color accentRose;
  final Color accentRoseSoft;

  // Merchant-only
  final Color flashDeal;
  final Color flashDealSoft;
  final Color flashDealSoftAlt;
  final Color whatsapp;

  bool get isDark => brightness == Brightness.dark;

  /// The palette every `AppColors.*` getter reads from. Swapped by the theme
  /// controller (see ShopxyApp) before the widget tree rebuilds. Defaults to
  /// [light] so colours resolve correctly before the controller loads.
  static AppPalette active = light;

  /// Calm, warm light theme — the original ShopXY look.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFF14181D),
    muted: Color(0xFF6A707A),
    subtle: Color(0xFF98A0AA),
    disabled: Color(0xFFC2C7CE),
    hairline: Color(0x1F14181D),
    surfaceTint: Color(0x0A14181D),
    canvas: Color(0xFFF8F7F3),
    pageTint: Color(0xFFFAFAF7),
    heroPanel: Color(0xFFEFEEE7),
    surface: Color(0xFFFFFFFF),
    onAccent: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFF14181D),
    onInverse: Color(0xFFFFFFFF),
    scrim: Color(0x6614181D),
    shadow: Color(0x14141D1D),
    brand: Color(0xFF1E8E5A),
    brandStrong: Color(0xFF146A42),
    brandSoft: Color(0xFFE6F2EC),
    success: Color(0xFF16A34A),
    successSoft: Color(0xFFE7F4EC),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFAEBD0),
    error: Color(0xFFB42318),
    errorSoft: Color(0xFFFCE9E7),
    info: Color(0xFF1D4ED8),
    infoSoft: Color(0xFFE3EAFE),
    accentTeal: Color(0xFF0E7C8A),
    accentTealSoft: Color(0xFFDDF1F3),
    accentIndigo: Color(0xFF4338CA),
    accentIndigoSoft: Color(0xFFE5E2FB),
    accentAmber: Color(0xFFA15C07),
    accentAmberSoft: Color(0xFFFAE9CC),
    accentRose: Color(0xFFB83A6F),
    accentRoseSoft: Color(0xFFFADFEB),
    flashDeal: Color(0xFFE05A2A),
    flashDealSoft: Color(0xFFFFE3D2),
    flashDealSoftAlt: Color(0xFFFFD2D2),
    whatsapp: Color(0xFF25D366),
  );

  /// Normal dark — deep slate canvas, raised surfaces, brightened brand. Soft
  /// status fills become low-alpha tints so chips don't glow on the dark ground.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFFE7EAEE),
    muted: Color(0xFF9AA3AD),
    subtle: Color(0xFF6C7682),
    disabled: Color(0xFF49515B),
    hairline: Color(0x1FFFFFFF),
    surfaceTint: Color(0x0DFFFFFF),
    canvas: Color(0xFF0F1419),
    pageTint: Color(0xFF141A20),
    heroPanel: Color(0xFF1C232B),
    // Surface == canvas: cards/inputs/sheets sit flat on the background and are
    // defined by hairline borders, not a different-shade fill. Keeps every
    // screen visually consistent (no "lighter card" vs "flat page" mismatch).
    surface: Color(0xFF0F1419),
    onAccent: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFFE7EAEE),
    onInverse: Color(0xFF11161B),
    scrim: Color(0xB3000000),
    shadow: Color(0x73000000),
    brand: Color(0xFF2FB877),
    brandStrong: Color(0xFF5FD99B),
    brandSoft: Color(0x262FB877),
    success: Color(0xFF3ECF86),
    successSoft: Color(0x263ECF86),
    warning: Color(0xFFE0A64A),
    warningSoft: Color(0x26E0A64A),
    error: Color(0xFFF0726A),
    errorSoft: Color(0x26F0726A),
    info: Color(0xFF6AA0F5),
    infoSoft: Color(0x266AA0F5),
    accentTeal: Color(0xFF3BBCCB),
    accentTealSoft: Color(0x263BBCCB),
    accentIndigo: Color(0xFF8B87F0),
    accentIndigoSoft: Color(0x268B87F0),
    accentAmber: Color(0xFFD99A3C),
    accentAmberSoft: Color(0x26D99A3C),
    accentRose: Color(0xFFE07AA6),
    accentRoseSoft: Color(0x26E07AA6),
    flashDeal: Color(0xFFF0793F),
    flashDealSoft: Color(0x26F0793F),
    flashDealSoftAlt: Color(0x26F05A5A),
    whatsapp: Color(0xFF25D366),
  );

  /// OLED — shares the dark palette but with a true-black canvas and near-black
  /// surfaces so unlit pixels stay off on OLED panels.
  static const AppPalette oled = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFFE7EAEE),
    muted: Color(0xFF9AA3AD),
    subtle: Color(0xFF6C7682),
    disabled: Color(0xFF49515B),
    hairline: Color(0x24FFFFFF),
    surfaceTint: Color(0x0DFFFFFF),
    canvas: Color(0xFF000000),
    pageTint: Color(0xFF060809),
    heroPanel: Color(0xFF14181D),
    // Surface == canvas (absolute black): cards/inputs/sheets are the exact
    // same black as the page, defined by hairline borders — no "lighter card"
    // shade. True flat OLED, consistent across every screen.
    surface: Color(0xFF000000),
    onAccent: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFFE7EAEE),
    onInverse: Color(0xFF11161B),
    scrim: Color(0xCC000000),
    shadow: Color(0x80000000),
    brand: Color(0xFF2FB877),
    brandStrong: Color(0xFF5FD99B),
    brandSoft: Color(0x262FB877),
    success: Color(0xFF3ECF86),
    successSoft: Color(0x263ECF86),
    warning: Color(0xFFE0A64A),
    warningSoft: Color(0x26E0A64A),
    error: Color(0xFFF0726A),
    errorSoft: Color(0x26F0726A),
    info: Color(0xFF6AA0F5),
    infoSoft: Color(0x266AA0F5),
    accentTeal: Color(0xFF3BBCCB),
    accentTealSoft: Color(0x263BBCCB),
    accentIndigo: Color(0xFF8B87F0),
    accentIndigoSoft: Color(0x268B87F0),
    accentAmber: Color(0xFFD99A3C),
    accentAmberSoft: Color(0x26D99A3C),
    accentRose: Color(0xFFE07AA6),
    accentRoseSoft: Color(0x26E07AA6),
    flashDeal: Color(0xFFF0793F),
    flashDealSoft: Color(0x26F0793F),
    flashDealSoftAlt: Color(0x26F05A5A),
    whatsapp: Color(0xFF25D366),
  );
}
