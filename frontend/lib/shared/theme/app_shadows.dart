import 'package:flutter/material.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> none = [];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> menu = [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> snackbar = [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}
