import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class HomeRecentlyViewed extends StatelessWidget {
  const HomeRecentlyViewed({super.key, required this.items});
  final List<ProductCard> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pick up where you left off',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: 4,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.brandSoft,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.md),
            itemBuilder: (context, i) => _RecentTile(product: items[i]),
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      padding: const EdgeInsets.all(AppSizes.sm),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: NetworkImageBox(
              url: resolveImageUrl(product.imageUrl),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              placeholderColor: product.bgColor,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.price,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.originalPrice,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
