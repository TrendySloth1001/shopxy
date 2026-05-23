import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Single filter pill used by any horizontal filter strip in the app.
/// Two states only — unselected (quiet `surfaceTint`) and selected
/// (filled with the pill's accent, defaulting to brand-black).
///
/// Heights and paddings come from [AppSizes] so the visual rhythm
/// stays in sync with the rest of the UI.
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
  final IconData? icon;

  /// Optional trailing affordance — used for picker-style pills that
  /// open a deeper UI on tap (e.g. a dropdown caret).
  final IconData? trailingIcon;

  /// Active-state fill colour. Also tints the icon when the pill is
  /// unselected, which subtly signals what tone the pill belongs to
  /// (e.g. warning-coloured "Low stock") without it shouting like a
  /// permanent selection.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = accent ?? AppColors.black;
    final fg = selected ? AppColors.white : AppColors.black;
    final bg = selected ? activeColor : AppColors.surfaceTint;
    final iconColor = selected ? AppColors.white : activeColor;

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
                  Icon(icon, size: AppSizes.iconSm - 2, color: iconColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 4),
                  Icon(trailingIcon, size: AppSizes.iconSm - 2, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal scroll-strip container for [AppFilterPill]s. Matches the
/// padding rhythm used by [AppSearchBar] above it so the two read as
/// one filter header.
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
