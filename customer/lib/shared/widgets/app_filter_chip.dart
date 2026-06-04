import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Selectable pill. Used for category strips, sort/filter rows, and
/// recent-search chips. Single source of truth for chip styling — do
/// not hand-roll filter pills inside feature files.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? AppColors.black : AppColors.white;
    final fg = selected ? AppColors.white : AppColors.black;
    final border = selected
        ? BorderSide.none
        : const BorderSide(color: AppColors.hairline);

    final shape = AppShapes.squircle(AppSizes.radiusFull, side: border);

    return Material(
      color: bg,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? AppSizes.md : AppSizes.lg,
            vertical: dense ? AppSizes.xs + 2 : AppSizes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 14 : AppSizes.iconSm, color: fg),
                const SizedBox(width: AppSizes.xs + 2),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 12 : 13,
                  letterSpacing: 0.1,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSizes.xs + 2),
                Icon(trailingIcon, size: dense ? 14 : AppSizes.iconSm, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
