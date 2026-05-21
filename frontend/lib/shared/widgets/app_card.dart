import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Standard card: white surface with hairline border. Tappable when onTap set.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.lg),
    this.onTap,
    this.radius = AppSizes.radiusLg,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final shape = AppShapes.squircle(
      radius,
      side: BorderSide(color: borderColor ?? AppColors.hairline, width: 1),
    );

    return Material(
      color: AppColors.white,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
