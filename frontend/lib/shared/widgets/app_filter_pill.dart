import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

class AppFilterPill extends StatelessWidget {
  const AppFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppIconData? icon;

  final AppIconData? trailingIcon;

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neutral = accent == null;
    final activeColor = accent ?? AppColors.inverseSurface;
    final selectedFg = neutral ? AppColors.onInverse : AppColors.white;
    final fg = selected ? selectedFg : AppColors.black;
    final bg = selected ? activeColor : AppColors.surfaceTint;
    final iconColor = selected ? selectedFg : activeColor;

    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sm),
      child: Material(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusFull),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  AppIcon(icon, size: AppSizes.iconSm - 2, color: iconColor),
                  const SizedBox(width: AppSizes.xs),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: AppSizes.xs),
                  AppIcon(trailingIcon, size: AppSizes.iconSm - 2, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppFilterStrip extends StatelessWidget {
  const AppFilterStrip({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: Row(children: children),
    );
  }
}
