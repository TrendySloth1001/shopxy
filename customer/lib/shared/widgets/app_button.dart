import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

enum AppButtonVariant { primary, secondary, danger, ghost }

enum AppButtonSize { sm, md, lg }

/// The one button widget for the app. Wraps Material buttons with consistent
/// two-tone styling, loading state, and optional leading/trailing icons.
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

  /// Primary CTA: solid black background, white text.
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

  /// Secondary: white background, black hairline border.
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

  /// Danger: solid error background, white text.
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

  /// Ghost: no background, no border — text-only action.
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
  final IconData? icon;
  final IconData? trailingIcon;
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
                Icon(icon, size: _iconSize, color: fg),
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
                Icon(trailingIcon, size: _iconSize, color: fg),
              ],
            ],
          );

    final btn = Material(
      color: bg,
      shape: AppShapes.squircle(AppSizes.radiusButton, side: border),
      child: InkWell(
        onTap: effectiveOnPressed,
        customBorder: AppShapes.squircle(AppSizes.radiusButton, side: border),
        splashColor: fg.withValues(alpha: 0.06),
        highlightColor: fg.withValues(alpha: 0.04),
        child: Padding(padding: _padding, child: Center(child: child)),
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
        return AppColors.black;
      case AppButtonVariant.danger:
        return AppColors.error;
      case AppButtonVariant.secondary:
      case AppButtonVariant.ghost:
        return AppColors.white;
    }
  }

  BorderSide _borderSide() {
    switch (variant) {
      case AppButtonVariant.secondary:
        return const BorderSide(color: AppColors.black, width: 1);
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
      case AppButtonVariant.ghost:
        return BorderSide.none;
    }
  }
}
