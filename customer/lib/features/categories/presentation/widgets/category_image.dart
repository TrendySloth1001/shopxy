import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class CategoryImage extends StatelessWidget {
  const CategoryImage({
    super.key,
    required this.category,
    this.fit = BoxFit.cover,
  });
  final Category category;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = category.imageUrl;
    final fallback = Container(
      color: AppColors.surfaceTint,
      alignment: Alignment.center,
      child: const AppIcon(
        AppIcons.categoryOutlined,
        color: AppColors.muted,
        size: AppSizes.iconXl,
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: AppColors.surfaceTint),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
