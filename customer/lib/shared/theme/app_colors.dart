import 'package:flutter/material.dart';

/// Calm, breathable palette. Designed to *not* attack the eye:
/// warm canvas page, near-black inks (not pure black), refined emerald
/// brand, and a small set of editorial accents for distinguishing
/// entity types (vendors / parties / categories / status).
///
/// Three groups:
///   1. Inks       — text + iconography
///   2. Surfaces   — canvas page bg + white card surfaces + hero panels
///   3. Accents    — brand, status, and editorial tints
class AppColors {
  AppColors._();

  // ── Inks ─────────────────────────────────────────────
  /// Primary ink. WhatsApp's near-black — reads as "black" in copy but is
  /// kinder to the eyes than pure #000.
  static const Color black = Color(0xFF111B21);

  /// Pure white reserved for floating surfaces (cards, sheets).
  static const Color white = Color(0xFFFFFFFF);

  /// Hairline border — cool graphite at low alpha.
  static const Color hairline = Color(0x1A111B21);

  /// Even softer wash — used for hover/pressed surfaces.
  static const Color surfaceTint = Color(0x08111B21);

  /// Secondary text (WhatsApp blue-grey).
  static const Color muted = Color(0xFF667781);

  /// Tertiary / placeholder text.
  static const Color subtle = Color(0xFF8696A0);

  /// Disabled foreground.
  static const Color disabled = Color(0xFFBFC8CE);

  // ── Surfaces ─────────────────────────────────────────
  /// WhatsApp's cool light-grey page background. White cards sit on top of
  /// this for subtle depth without shadows, at lower glare than warm cream.
  static const Color canvas = Color(0xFFF0F2F5);

  /// Slightly lighter tint — legacy alias kept for older callers.
  static const Color pageTint = Color(0xFFF6F7F9);

  /// Soft panel used behind hero illustrations — a half-step deeper than the
  /// canvas so illustrations have a backdrop.
  static const Color heroPanel = Color(0xFFE4E8EB);

  // ── Brand ────────────────────────────────────────────
  /// WhatsApp teal-green — confident, calm, not loud.
  static const Color brand = Color(0xFF008069);
  static const Color brandStrong = Color(0xFF006E5A);

  /// Pale brand wash — chip fills, soft accent surfaces.
  static const Color brandSoft = Color(0xFFE7F3EF);

  // ── Status (soft tones) ──────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE7F4EC);

  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFAEBD0);

  static const Color error = Color(0xFFB42318);
  static const Color errorSoft = Color(0xFFFCE9E7);

  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFE3EAFE);

  // ── Editorial accents ────────────────────────────────
  /// Used sparingly to tag distinct entity classes — vendors,
  /// parties, categories, challans. Each comes with a soft fill so
  /// chips, monograms, and tiles can read as a family.
  static const Color accentTeal = Color(0xFF0E7C8A);
  static const Color accentTealSoft = Color(0xFFDDF1F3);

  static const Color accentIndigo = Color(0xFF4338CA);
  static const Color accentIndigoSoft = Color(0xFFE5E2FB);

  static const Color accentAmber = Color(0xFFA15C07);
  static const Color accentAmberSoft = Color(0xFFFAE9CC);

  static const Color accentRose = Color(0xFFB83A6F);
  static const Color accentRoseSoft = Color(0xFFFADFEB);

  // ── Rating / flash accent ────────────────────────────
  /// Warm accent for rating stars and flash highlights.
  /// Mirrors customer-web `--color-flash-accent`.
  static const Color flashAccent = Color(0xFFE05A2A);

  // ── Category tints ───────────────────────────────────
  /// Rotating soft background tints for letter-monogram fallbacks
  /// (category pucks, tiles, headers). Single source so those surfaces
  /// stay in sync — mirrors customer-web `CATEGORY_TINTS`.
  static const List<Color> categoryTints = [
    Color(0xFFE3E8F4),
    Color(0xFFF3E4D6),
    Color(0xFFF9E1EA),
    Color(0xFFE6F2EC),
    Color(0xFFEFE9DD),
    Color(0xFFE0E1E6),
    Color(0xFFE7DFD4),
    Color(0xFFE4DECF),
    Color(0xFFE6F2DA),
    Color(0xFFDEEAF1),
  ];
}
