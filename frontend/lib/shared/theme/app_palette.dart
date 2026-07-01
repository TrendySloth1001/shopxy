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
    required this.field,
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

  /// Input/field fill. Distinct from [surface] so text fields stay defined even
  /// where cards are flat (surface == canvas in dark/OLED): white in light, a
  /// raised dark in dark/OLED.
  final Color field;

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
    field: Color(0xFFFFFFFF),
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

  /// Beige — a second light-family theme: soft sepia paper. Warm dark ink on a
  /// beige canvas with cream raised surfaces; lower glare than the white light
  /// theme. Brand + status foregrounds are shared with [light]; only the surface
  /// /ink neutrals and the warm-tinted soft fills differ. Mirrors the
  /// `html[data-theme="beige"]` block in the web app's globals.css.
  static const AppPalette beige = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFF241F16),
    muted: Color(0xFF6D6450),
    subtle: Color(0xFF948A72),
    disabled: Color(0xFFC0B6A0),
    hairline: Color(0x24241F16),
    surfaceTint: Color(0x0A241F16),
    canvas: Color(0xFFECE3D1),
    pageTint: Color(0xFFF1E9D9),
    heroPanel: Color(0xFFE0D5BE),
    surface: Color(0xFFF8F2E6),
    field: Color(0xFFFBF6EC),
    onAccent: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFF241F16),
    onInverse: Color(0xFFF4EEDE),
    scrim: Color(0x66211B10),
    shadow: Color(0x1A241F16),
    brand: Color(0xFF1E8E5A),
    brandStrong: Color(0xFF146A42),
    brandSoft: Color(0xFFE4EFDF),
    success: Color(0xFF16A34A),
    successSoft: Color(0xFFE6F1E2),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFF5E7CB),
    error: Color(0xFFB42318),
    errorSoft: Color(0xFFF7E6DE),
    info: Color(0xFF1D4ED8),
    infoSoft: Color(0xFFE3E9F6),
    accentTeal: Color(0xFF0E7C8A),
    accentTealSoft: Color(0xFFDAEDEE),
    accentIndigo: Color(0xFF4338CA),
    accentIndigoSoft: Color(0xFFE5E2F6),
    accentAmber: Color(0xFFA15C07),
    accentAmberSoft: Color(0xFFF5E6CB),
    accentRose: Color(0xFFB83A6F),
    accentRoseSoft: Color(0xFFF5DDE8),
    flashDeal: Color(0xFFE05A2A),
    flashDealSoft: Color(0xFFFFE1CF),
    flashDealSoftAlt: Color(0xFFFFD0CB),
    whatsapp: Color(0xFF25D366),
  );

  /// Rose — a light-family theme: warm blush / rosé. Warm plum-dark ink on a
  /// soft pink canvas with lighter blush surfaces. Brand + status foregrounds
  /// are shared with [light]; only neutrals and soft fills are re-tinted.
  /// Mirrors the `html[data-theme="rose"]` block in the web app's globals.css.
  static const AppPalette rose = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFF3A2530),
    muted: Color(0xFF8A6D78),
    subtle: Color(0xFFB394A1),
    disabled: Color(0xFFD9C2CB),
    hairline: Color(0x1F3A2530),
    surfaceTint: Color(0x0A3A2530),
    canvas: Color(0xFFFBF0F2),
    pageTint: Color(0xFFFDF5F6),
    heroPanel: Color(0xFFF6E2E7),
    surface: Color(0xFFFFF7F9),
    field: Color(0xFFFFFAFB),
    onAccent: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFF3A2530),
    onInverse: Color(0xFFFBEEF2),
    scrim: Color(0x662A0F1A),
    shadow: Color(0x1A3A2530),
    brand: Color(0xFF1E8E5A),
    brandStrong: Color(0xFF146A42),
    brandSoft: Color(0xFFE2F0E8),
    success: Color(0xFF16A34A),
    successSoft: Color(0xFFE6F1E6),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFF6E7CD),
    error: Color(0xFFB42318),
    errorSoft: Color(0xFFF9E3E3),
    info: Color(0xFF1D4ED8),
    infoSoft: Color(0xFFE6E9F7),
    accentTeal: Color(0xFF0E7C8A),
    accentTealSoft: Color(0xFFDBEEF0),
    accentIndigo: Color(0xFF4338CA),
    accentIndigoSoft: Color(0xFFE9E2F4),
    accentAmber: Color(0xFFA15C07),
    accentAmberSoft: Color(0xFFF6E6CD),
    accentRose: Color(0xFFB83A6F),
    accentRoseSoft: Color(0xFFF9DBE8),
    flashDeal: Color(0xFFE05A2A),
    flashDealSoft: Color(0xFFFFE0D4),
    flashDealSoftAlt: Color(0xFFFFD2D8),
    whatsapp: Color(0xFF25D366),
  );

  /// Sage — a light-family theme: cool mint-green, calm. Deep green-dark ink on
  /// a soft mint canvas with lighter surfaces. Mirrors the
  /// `html[data-theme="sage"]` block in the web app's globals.css.
  static const AppPalette sage = AppPalette(
    brightness: Brightness.light,
    ink: Color(0xFF1C2B23),
    muted: Color(0xFF5D7268),
    subtle: Color(0xFF8AA093),
    disabled: Color(0xFFC0CFC6),
    hairline: Color(0x1F1C2B23),
    surfaceTint: Color(0x0A1C2B23),
    canvas: Color(0xFFEAF1EA),
    pageTint: Color(0xFFF0F6F0),
    heroPanel: Color(0xFFDBE7DD),
    surface: Color(0xFFF5FAF5),
    field: Color(0xFFF9FDF9),
    onAccent: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFF1C2B23),
    onInverse: Color(0xFFEAF3EE),
    scrim: Color(0x660C1811),
    shadow: Color(0x1A1C2B23),
    brand: Color(0xFF1E8E5A),
    brandStrong: Color(0xFF146A42),
    brandSoft: Color(0xFFDCECDF),
    success: Color(0xFF16A34A),
    successSoft: Color(0xFFE4F1E4),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFF4E7CB),
    error: Color(0xFFB42318),
    errorSoft: Color(0xFFF7E5E0),
    info: Color(0xFF1D4ED8),
    infoSoft: Color(0xFFE2E9F5),
    accentTeal: Color(0xFF0E7C8A),
    accentTealSoft: Color(0xFFD7ECEC),
    accentIndigo: Color(0xFF4338CA),
    accentIndigoSoft: Color(0xFFE3E2F2),
    accentAmber: Color(0xFFA15C07),
    accentAmberSoft: Color(0xFFF3E6C9),
    accentRose: Color(0xFFB83A6F),
    accentRoseSoft: Color(0xFFF3DDE6),
    flashDeal: Color(0xFFE05A2A),
    flashDealSoft: Color(0xFFFFE1D0),
    flashDealSoftAlt: Color(0xFFFFD2CD),
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
    // Inputs stay a defined raised dark even though cards are flat.
    field: Color(0xFF1C232B),
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
    // Inputs get a subtle raised fill so fields stay visible on pure black.
    field: Color(0xFF14181D),
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

  /// Midnight — a dark-family theme: deep navy / indigo. Light ink on a
  /// navy-black canvas; brand emerald brightened for the ground. Mirrors the
  /// `html[data-theme="midnight"]` block in the web app's globals.css.
  static const AppPalette midnight = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFFE6E9F2),
    muted: Color(0xFF9AA3C4),
    subtle: Color(0xFF6B7396),
    disabled: Color(0xFF454D70),
    hairline: Color(0x1FFFFFFF),
    surfaceTint: Color(0x0DFFFFFF),
    canvas: Color(0xFF0D1220),
    pageTint: Color(0xFF111730),
    heroPanel: Color(0xFF1A2240),
    surface: Color(0xFF141B30),
    field: Color(0xFF1A2240),
    onAccent: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFFE6E9F2),
    onInverse: Color(0xFF141A2E),
    scrim: Color(0xB3000000),
    shadow: Color(0x73000000),
    brand: Color(0xFF34C07F),
    brandStrong: Color(0xFF6FE0A6),
    brandSoft: Color(0x2634C07F),
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

  /// Nord — a dark-family theme: muted arctic blue-grey (the Nord palette).
  /// Softer than the deep-slate dark; status colours take on Nord's aurora
  /// hues. Mirrors the `html[data-theme="nord"]` block in the web globals.css.
  static const AppPalette nord = AppPalette(
    brightness: Brightness.dark,
    ink: Color(0xFFE5E9F0),
    muted: Color(0xFF9AA4B8),
    subtle: Color(0xFF6D7688),
    disabled: Color(0xFF4C566A),
    hairline: Color(0x1AFFFFFF),
    surfaceTint: Color(0x0DFFFFFF),
    canvas: Color(0xFF2E3440),
    pageTint: Color(0xFF333A47),
    heroPanel: Color(0xFF3B4252),
    surface: Color(0xFF3B4252),
    field: Color(0xFF434C5E),
    onAccent: Color(0xFFFFFFFF),
    inverseSurface: Color(0xFFE5E9F0),
    onInverse: Color(0xFF2E3440),
    scrim: Color(0xB3000000),
    shadow: Color(0x66000000),
    brand: Color(0xFF6BCF9A),
    brandStrong: Color(0xFF8FE0B3),
    brandSoft: Color(0x266BCF9A),
    success: Color(0xFFA3BE8C),
    successSoft: Color(0x26A3BE8C),
    warning: Color(0xFFEBCB8B),
    warningSoft: Color(0x26EBCB8B),
    error: Color(0xFFBF616A),
    errorSoft: Color(0x26BF616A),
    info: Color(0xFF81A1C1),
    infoSoft: Color(0x2681A1C1),
    accentTeal: Color(0xFF88C0D0),
    accentTealSoft: Color(0x2688C0D0),
    accentIndigo: Color(0xFF8F9CE0),
    accentIndigoSoft: Color(0x268F9CE0),
    accentAmber: Color(0xFFD08770),
    accentAmberSoft: Color(0x26D08770),
    accentRose: Color(0xFFD08FB0),
    accentRoseSoft: Color(0x26D08FB0),
    flashDeal: Color(0xFFD08770),
    flashDealSoft: Color(0x26D08770),
    flashDealSoftAlt: Color(0x26BF616A),
    whatsapp: Color(0xFF25D366),
  );
}
