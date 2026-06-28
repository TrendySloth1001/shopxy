import 'package:flutter/material.dart';
import 'package:shopxy/shared/theme/app_palette.dart';

/// Calm, breathable palette. Designed to *not* attack the eye: warm canvas
/// page, near-black inks (not pure black), refined emerald brand, and a small
/// set of editorial accents for distinguishing entity types.
///
/// These are now **theme-aware getters** that read [AppPalette.active] — the
/// palette swapped by the theme controller (see ShopxyApp) for light / dark /
/// OLED. Because they're getters (not `const`), they re-resolve on every build,
/// so the whole app re-tints when the theme changes without touching call
/// sites. (This is why a colour can't be used in a `const` constructor any
/// more — drop the `const` at those sites.)
///
/// Role notes for the few tokens whose meaning matters when theming:
///   • [white]  — literal white *foreground* on a coloured fill (button text,
///                FAB icon). Stays white in every theme. For a card/sheet/input
///                *surface* use [surface] instead.
///   • [black]  — primary text/icon ink. Flips light on dark.
///   • [surface]/[inverseSurface]/[scrim] — see [AppPalette].
class AppColors {
  AppColors._();

  static AppPalette get _p => AppPalette.active;

  // ── Inks ─────────────────────────────────────────────
  /// Primary ink — text + iconography. Flips light in dark themes.
  static Color get black => _p.ink;

  /// Literal white foreground for text/icons on a coloured fill. White in every
  /// theme. (For a raised surface use [surface], not this.)
  static Color get white => _p.onAccent;

  /// Hairline border — warm graphite at low alpha (light at low alpha on dark).
  static Color get hairline => _p.hairline;

  /// Soft wash for hover/pressed surfaces.
  static Color get surfaceTint => _p.surfaceTint;

  /// Secondary text.
  static Color get muted => _p.muted;

  /// Tertiary / placeholder text.
  static Color get subtle => _p.subtle;

  /// Disabled foreground.
  static Color get disabled => _p.disabled;

  // ── Surfaces ─────────────────────────────────────────
  /// Global page background.
  static Color get canvas => _p.canvas;

  /// Slightly cooler tint — legacy alias kept for older callers.
  static Color get pageTint => _p.pageTint;

  /// Soft panel behind hero illustrations — a half-step deeper than canvas.
  static Color get heroPanel => _p.heroPanel;

  /// Raised card / input / sheet surface. White in light; a step above the
  /// canvas in dark. Use this for floating surfaces — never [white].
  static Color get surface => _p.surface;

  /// Input/text-field fill — distinct from [surface] (white in light, a raised
  /// dark in dark/OLED) so fields stay defined where cards are flat.
  static Color get field => _p.field;

  /// High-contrast neutral fill (avatar, monogram, selected pill): dark in
  /// light mode, light in dark mode. Pair with [onInverse] for its text.
  static Color get inverseSurface => _p.inverseSurface;

  /// Foreground on [inverseSurface].
  static Color get onInverse => _p.onInverse;

  /// Modal / drawer barrier. Near-black in every theme so it always dims.
  static Color get scrim => _p.scrim;

  /// Ambient shadow ink — black at low alpha, deeper on dark.
  static Color get shadow => _p.shadow;

  // ── Brand ────────────────────────────────────────────
  static Color get brand => _p.brand;
  static Color get brandStrong => _p.brandStrong;
  static Color get brandSoft => _p.brandSoft;

  // ── Status (soft tones) ──────────────────────────────
  static Color get success => _p.success;
  static Color get successSoft => _p.successSoft;
  static Color get warning => _p.warning;
  static Color get warningSoft => _p.warningSoft;
  static Color get error => _p.error;
  static Color get errorSoft => _p.errorSoft;
  static Color get info => _p.info;
  static Color get infoSoft => _p.infoSoft;

  // ── Editorial accents ────────────────────────────────
  static Color get accentTeal => _p.accentTeal;
  static Color get accentTealSoft => _p.accentTealSoft;
  static Color get accentIndigo => _p.accentIndigo;
  static Color get accentIndigoSoft => _p.accentIndigoSoft;
  static Color get accentAmber => _p.accentAmber;
  static Color get accentAmberSoft => _p.accentAmberSoft;
  static Color get accentRose => _p.accentRose;
  static Color get accentRoseSoft => _p.accentRoseSoft;

  // ── Merchant-only ────────────────────────────────────
  static Color get flashDeal => _p.flashDeal;
  static Color get flashDealSoft => _p.flashDealSoft;
  static Color get flashDealSoftAlt => _p.flashDealSoftAlt;
  static Color get whatsapp => _p.whatsapp;

  /// Background for an avatar / monogram / icon-puck *tile*. In light mode it
  /// uses the supplied soft accent (colourful, recognisable); in dark / OLED it
  /// collapses to a neutral dark puck ([heroPanel]) so large tinted squares
  /// don't clash with the near-black background. The icon/letter on top keeps
  /// its accent colour, so identity is preserved without a glowing tile.
  static Color tileBg(Color softInLight) =>
      _p.isDark ? _p.heroPanel : softInLight;
}
