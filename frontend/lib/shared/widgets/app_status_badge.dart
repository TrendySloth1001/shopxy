import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

enum AppStatusTone { neutral, success, warning, error, info }

/// Visual weight of the badge.
///
/// * [outline] — hairline border, transparent surface. The quiet default,
///   used for steady states like a stock count in good standing.
/// * [soft]   — tinted background with the tone's strong colour for text.
///   Calls attention without shouting; sits between outline and filled.
/// * [filled] — fully filled background with white text. Reserved for
///   states the user needs to react to (out of stock, declined, error).
enum AppStatusWeight { outline, soft, filled }

/// Small pill used for status labels: stock counts, invoice status,
/// order status, etc. Three weights so urgent things can be visually
/// louder than steady-state things in the same row.
class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.weight = AppStatusWeight.outline,
    this.icon,
    this.dense = false,
  });

  final String label;
  final AppStatusTone tone;
  final AppStatusWeight weight;
  final AppIconData? icon;
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

  Color get _soft {
    switch (tone) {
      case AppStatusTone.neutral:
      case AppStatusTone.info:
        return AppColors.surfaceTint;
      case AppStatusTone.success:
        return AppColors.successSoft;
      case AppStatusTone.warning:
        return AppColors.warningSoft;
      case AppStatusTone.error:
        return AppColors.errorSoft;
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

    final Color bg;
    final Color fg;
    final BorderSide side;
    switch (weight) {
      case AppStatusWeight.outline:
        bg = AppColors.surface;
        fg = _color;
        side = BorderSide(color: _color, width: 1);
      case AppStatusWeight.soft:
        bg = _soft;
        fg = _color;
        side = BorderSide.none;
      case AppStatusWeight.filled:
        bg = _color;
        fg = AppColors.white;
        side = BorderSide.none;
    }

    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull, side: side),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: AppSizes.iconSm - 2, color: fg),
            const SizedBox(width: AppSizes.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
