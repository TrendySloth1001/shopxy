import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Square (squircle) icon container — used as a leading element in list rows.
/// Two variants:
/// * [AppIconAvatar] (filled black) — for emphasis (FAB-like).
/// * [AppIconAvatar.outlined] — neutral hairline border, black icon.
class AppIconAvatar extends StatelessWidget {
  const AppIconAvatar({
    super.key,
    required this.icon,
    this.size = AppSizes.avatarSm,
    this.filled = true,
  });

  const AppIconAvatar.outlined({
    super.key,
    required this.icon,
    this.size = AppSizes.avatarSm,
  }) : filled = false;

  final AppIconData icon;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: filled ? AppColors.inverseSurface : AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(
            color: filled ? AppColors.inverseSurface : AppColors.hairline,
            width: 1,
          ),
        ),
      ),
      child: AppIcon(
        icon,
        size: size * 0.5,
        color: filled ? AppColors.onInverse : AppColors.black,
      ),
    );
  }
}

/// Circular monogram avatar — letter on hairline-bordered surface circle.
class AppMonogramAvatar extends StatelessWidget {
  const AppMonogramAvatar({
    super.key,
    required this.label,
    this.size = AppSizes.avatarSm,
  });

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = label.isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.inverseSurface,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: theme.textTheme.labelLarge?.copyWith(
          color: AppColors.onInverse,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
