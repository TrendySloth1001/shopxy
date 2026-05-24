import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/categories/domain/entities/category.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Shared network-image renderer for category artwork. Falls back to a
/// tinted box (with an optional Material icon) when the URL is null or
/// the fetch errors. Used by the grid, the rail, and the chip.
class CategoryImage extends StatelessWidget {
  const CategoryImage({super.key, required this.category, this.fit = BoxFit.cover});
  final Category category;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = category.imageUrl;
    final fallback = Container(
      color: AppColors.surfaceTint,
      alignment: Alignment.center,
      child: const Icon(Icons.category_outlined, color: AppColors.muted, size: 28),
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
