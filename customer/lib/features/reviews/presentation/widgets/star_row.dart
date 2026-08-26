import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.rating,
    this.size = AppSizes.iconSm,
    this.color = AppColors.success,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final delta = rating - i;
        AppIconData icon;
        if (delta >= 0.75) {
          icon = AppIcons.starRounded;
        } else if (delta >= 0.25) {
          icon = AppIcons.starHalfRounded;
        } else {
          icon = AppIcons.starOutlineRounded;
        }
        return AppIcon(icon, size: size, color: color);
      }),
    );
  }
}
