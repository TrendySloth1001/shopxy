import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    this.subtitle,
    this.action,
  }) : assert(
         icon != null || illustration != null,
         'Pass either icon or illustration',
       );

  EmptyState.line({
    Key? key,
    required LineArt kind,
    required String title,
    String? subtitle,
    Widget? action,
  }) : this(
         key: key,
         illustration: LineIllustration(kind: kind, size: 140),
         title: title,
         subtitle: subtitle,
         action: action,
       );

  EmptyState.image({
    Key? key,
    required String asset,
    required String title,
    String? subtitle,
    Widget? action,
    double size = 140,
  }) : this(
         key: key,
         illustration: SizedBox(
           width: size,
           height: size,
           child: Image.asset(asset, fit: BoxFit.contain),
         ),
         title: title,
         subtitle: subtitle,
         action: action,
       );

  final AppIconData? icon;
  final Widget? illustration;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 220,
              height: 180,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusLg),
              ),
              child:
                  illustration ??
                  AppIcon(
                    icon,
                    size: AppSizes.iconHuge,
                    color: AppColors.muted,
                  ),
            ),
            const SizedBox(height: AppSizes.xl),
            Text(
              title,
              style: theme.textTheme.titleLarge?.bold,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSizes.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSizes.xxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
