import 'package:flutter/material.dart';

/// Shopxy 4-color palette — vintage beige + OLED black.
///
/// 1. Ink       – the darkest tone (text on light, background on dark)
/// 2. Paper     – the lightest tone (background on light, text on dark)
/// 3. Stone     – mid-tone beige (cards, borders, muted elements)
/// 4. Espresso  – warm accent (CTAs, highlights, active states)
class AppColors {
  AppColors._();

  // ── The 4 palette colors ───────────────────────────
  static const Color ink = Color(0xFF000000);       // OLED black
  static const Color paper = Color(0xFFF5F0E8);     // warm off-white
  static const Color stone = Color(0xFFD6CEC4);     // muted beige
  static const Color espresso = Color(0xFF3C2A14);  // deep warm brown

  // ── Semantic mappings (derived from the 4 above) ───
  // Light mode
  static const Color lightBackground = paper;
  static const Color lightSurface = Color(0xFFEDE8DF);    // paper darkened slightly
  static const Color lightOnBackground = ink;
  static const Color lightOnSurface = ink;
  static const Color lightOutline = stone;
  static const Color lightMuted = Color(0xFF8A8078);       // stone darkened for text

  // Dark mode (OLED)
  static const Color darkBackground = ink;
  static const Color darkSurface = Color(0xFF1A1612);      // barely-there warm black
  static const Color darkOnBackground = paper;
  static const Color darkOnSurface = paper;
  static const Color darkOutline = Color(0xFF3A332C);      // stone at very low brightness
  static const Color darkMuted = Color(0xFF9E958A);        // stone lightened for text

  // Status (kept minimal — tinted from palette)
  static const Color success = Color(0xFF4A7A5B);
  static const Color error = Color(0xFF8B3A2F);
  static const Color warning = Color(0xFFA67C3D);
}
