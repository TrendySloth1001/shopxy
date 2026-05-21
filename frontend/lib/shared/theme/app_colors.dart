import 'package:flutter/material.dart';

/// Two-tone palette. Pure white + pure black, with a single hairline
/// for borders/dividers, plus status accents.
///
/// Do NOT introduce greys, gradients, or surface shades outside this file.
class AppColors {
  AppColors._();

  // ── Base tones ─────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  /// The one allowed neutral — used for hairline borders and subtle dividers.
  /// Black at ~10% opacity, kept as a const ARGB literal so it works in
  /// `const` constructors.
  static const Color hairline = Color(0x1A000000);

  /// Even softer hairline for hover/pressed surfaces — black at ~4%.
  static const Color surfaceTint = Color(0x0A000000);

  /// Muted text — black at ~56% opacity for secondary labels.
  static const Color muted = Color(0x8F000000);

  /// Disabled foreground — black at ~32% opacity.
  static const Color disabled = Color(0x52000000);

  // ── Status accents ─────────────────────────────────
  // Used sparingly: only for errors, success confirmation, and warnings.
  static const Color error = Color(0xFFD92D20);
  static const Color success = Color(0xFF067647);
  static const Color warning = Color(0xFFB54708);
}
