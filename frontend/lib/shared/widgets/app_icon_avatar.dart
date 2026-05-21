import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Square (squircle) icon container — used as a leading element in list rows.
/// Two variants:
/// * [AppIconAvatar] (filled black) — for emphasis (FAB-like).
/// * [AppIconAvatar.outlined] — neutral hairline border, black icon.
class AppIconAvatar extends StatelessWidget {
  const AppIconAvatar({
    super.key,
    required this.icon,
    this.size = 40,
    this.filled = true,
  });

  const AppIconAvatar.outlined({
    super.key,
    required this.icon,
    this.size = 40,
  }) : filled = false;

  final IconData icon;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: filled ? AppColors.black : AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(
            color: filled ? AppColors.black : AppColors.hairline,
            width: 1,
          ),
        ),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: filled ? AppColors.white : AppColors.black,
      ),
    );
  }
}

/// Circular monogram avatar — letter on hairline-bordered white circle.
class AppMonogramAvatar extends StatelessWidget {
  const AppMonogramAvatar({super.key, required this.label, this.size = 40});

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
        color: AppColors.black,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: theme.textTheme.labelLarge?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
