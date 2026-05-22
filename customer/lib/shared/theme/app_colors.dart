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
  /// Primary ink. Warm near-black — kinder to eyes than pure #000
  /// while still reading as "black" in copy.
  static const Color black = Color(0xFF14181D);

  /// Pure white reserved for floating surfaces (cards, sheets).
  static const Color white = Color(0xFFFFFFFF);

  /// Hairline border — warm graphite at low alpha.
  static const Color hairline = Color(0x1F14181D);

  /// Even softer wash — used for hover/pressed surfaces.
  static const Color surfaceTint = Color(0x0A14181D);

  /// Secondary text.
  static const Color muted = Color(0xFF6A707A);

  /// Tertiary / placeholder text.
  static const Color subtle = Color(0xFF98A0AA);

  /// Disabled foreground.
  static const Color disabled = Color(0xFFC2C7CE);

  // ── Surfaces ─────────────────────────────────────────
  /// Warm parchment used as the global page background. White cards
  /// sit on top of this for subtle depth without shadows.
  static const Color canvas = Color(0xFFF8F7F3);

  /// Slightly cooler tint — legacy alias kept for older callers.
  static const Color pageTint = Color(0xFFFAFAF7);

  /// Soft panel used behind hero illustrations — picks up the canvas
  /// tone a half-step deeper so illustrations have a backdrop.
  static const Color heroPanel = Color(0xFFEFEEE7);

  // ── Brand ────────────────────────────────────────────
  /// Refined emerald. Same family as the Glassdoor green that
  /// preceded it, dropped a few notches in saturation so it reads
  /// confident, not loud.
  static const Color brand = Color(0xFF1E8E5A);
  static const Color brandStrong = Color(0xFF146A42);

  /// Pale brand wash — chip fills, soft accent surfaces.
  static const Color brandSoft = Color(0xFFE6F2EC);

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
}
