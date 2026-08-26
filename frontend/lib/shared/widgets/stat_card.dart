import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
    this.emphasis = false,
  });

  final String title;
  final String value;
  final AppIconData icon;
  final VoidCallback? onTap;

  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = emphasis ? AppColors.white : AppColors.black;
    final mutedFg = emphasis
        ? AppColors.white.withValues(alpha: 0.7)
        : AppColors.muted;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppIcon(icon, size: AppSizes.iconMd, color: fg),
        const SizedBox(height: AppSizes.md),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(title, style: theme.textTheme.bodySmall?.copyWith(color: mutedFg)),
      ],
    );

    if (emphasis) {
      return Material(
        color: AppColors.inverseSurface,
        shape: Theme.of(context).cardTheme.shape,
        child: InkWell(
          onTap: onTap,
          customBorder: Theme.of(context).cardTheme.shape,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: content,
          ),
        ),
      );
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.lg),
      child: content,
    );
  }
}
