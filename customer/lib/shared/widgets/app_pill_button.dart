import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

class AppPillButton extends StatelessWidget {
  const AppPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color = AppColors.black,
    this.foreground = AppColors.white,
    this.height = AppSizes.fabSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIconData? icon;
  final bool loading;
  final Color color;
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !loading;
    return Material(
      color: disabled ? AppColors.disabled : color,
      shape: AppShapes.squircle(height / 2),
      child: InkWell(
        customBorder: AppShapes.squircle(height / 2),
        onTap: loading ? null : onPressed,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: loading
              ? Center(
                  child: SizedBox(
                    width: AppSizes.xl,
                    height: AppSizes.xl,
                    child: CircularProgressIndicator(
                      color: foreground,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: AppSizes.sm),
                      AppIcon(icon, color: foreground, size: AppSizes.iconMd),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
