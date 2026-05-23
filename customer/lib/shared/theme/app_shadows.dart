import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Elevation tokens. The customer app is deliberately flat — we use
/// hairline borders for grouping rather than drop shadows — but a few
/// floating surfaces (sticky bottom bars, dropdowns over content,
/// snackbars) need a faint shadow to read as floating.
///
/// All shadows are based on the warm-black ink at low alpha so they
/// land softly on the canvas background.
class AppShadows {
  AppShadows._();

  /// No elevation. Default for cards, list rows, sheets.
  static const List<BoxShadow> none = [];

  /// Whisper shadow — sticky bottom CTA, floating chips. Just enough
  /// to lift the surface off the canvas without screaming.
  static List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Dropdown / menu / autocomplete panel. A little stronger so the
  /// menu reads as on top of content.
  static List<BoxShadow> menu = [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Snackbar / toast. Stronger still because it appears at the edge
  /// and needs to be readable against any underlying content.
  static List<BoxShadow> snackbar = [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}
