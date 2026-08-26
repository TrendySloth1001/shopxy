import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final AppIconData icon;
  final String title;
  final String body;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: true,
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSizes.massive,
                height: AppSizes.massive,
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusLg),
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  icon,
                  color: AppColors.muted,
                  size: AppSizes.iconXl,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Text(
                title,
                style: theme.textTheme.titleMedium?.bold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: AppSizes.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
