import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

enum AppStatusTone { neutral, success, warning, error, info }

/// Small pill used for status labels: paid, pending, low stock, out of stock,
/// stock in/out, etc. Outline-only, never filled — keeps the surface white.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  final bool dense;

  Color get _color {
    switch (tone) {
      case AppStatusTone.neutral:
      case AppStatusTone.info:
        return AppColors.black;
      case AppStatusTone.success:
        return AppColors.success;
      case AppStatusTone.warning:
        return AppColors.warning;
      case AppStatusTone.error:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = dense
        ? const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2)
        : const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.xs,
          );

    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusFull,
          side: BorderSide(color: _color, width: 1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconSm - 2, color: _color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
