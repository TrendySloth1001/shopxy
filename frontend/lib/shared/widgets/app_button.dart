import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.danger;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AppButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final AppIconData? icon;
  final AppIconData? trailingIcon;
  final bool isLoading;
  final bool fullWidth;

  EdgeInsets get _padding {
    switch (size) {
      case AppButtonSize.sm:
        return const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        );
      case AppButtonSize.md:
        return const EdgeInsets.symmetric(
          horizontal: AppSizes.xl,
          vertical: AppSizes.md,
        );
      case AppButtonSize.lg:
        return const EdgeInsets.symmetric(
          horizontal: AppSizes.xxl,
          vertical: AppSizes.lg,
        );
    }
  }

  double get _iconSize {
    switch (size) {
      case AppButtonSize.sm:
        return AppSizes.iconSm;
      case AppButtonSize.md:
        return AppSizes.iconMd;
      case AppButtonSize.lg:
        return AppSizes.iconMd;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveOnPressed = isLoading ? null : onPressed;

    final fg = _foregroundColor();
    final bg = _backgroundColor();
    final border = _borderSide();

    final child = isLoading
        ? SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                AppIcon(icon, size: _iconSize, color: fg),
                const SizedBox(width: AppSizes.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSizes.sm),
                AppIcon(trailingIcon, size: _iconSize, color: fg),
              ],
            ],
          );

    final btn = Material(
      color: bg,
      shape: AppShapes.squircle(AppSizes.radiusFull, side: border),
      child: InkWell(
        onTap: effectiveOnPressed,
        customBorder: AppShapes.squircle(AppSizes.radiusFull, side: border),
        splashColor: fg.withValues(alpha: 0.06),
        highlightColor: fg.withValues(alpha: 0.04),
        child: Padding(
          padding: _padding,
          child: Center(
            heightFactor: 1,
            child: child,
          ),
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }

  Color _foregroundColor() {
    if (onPressed == null && !isLoading) return AppColors.disabled;
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.onInverse;
      case AppButtonVariant.danger:
        return AppColors.white;
      case AppButtonVariant.secondary:
      case AppButtonVariant.ghost:
        return AppColors.black;
    }
  }

  Color _backgroundColor() {
    if (onPressed == null && !isLoading) {
      return variant == AppButtonVariant.ghost
          ? Colors.transparent
          : AppColors.hairline;
    }
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.inverseSurface;
      case AppButtonVariant.danger:
        return AppColors.error;
      case AppButtonVariant.secondary:
        return AppColors.surface;
      case AppButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  BorderSide _borderSide() {
    switch (variant) {
      case AppButtonVariant.secondary:
        return BorderSide(color: AppColors.black, width: 1);
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
      case AppButtonVariant.ghost:
        return BorderSide.none;
    }
  }
}
