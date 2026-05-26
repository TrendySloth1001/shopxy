import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class HomeCollectionBanner extends StatelessWidget {
  const HomeCollectionBanner({super.key, required this.tiles, this.title, this.subtitle});

  final List<CollectionTile> tiles;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final visibleTiles = tiles.take(4).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        decoration: ShapeDecoration(
          color: const Color(0xFFF4F757),
          shape: AppShapes.squircle(AppSizes.radiusLg),
        ),
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? 'Editorial Collection',
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle ?? 'Curated picks from our editors',
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '0% EMI',
                    style: TextStyle(
                      color: Color(0xFFF4F757),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                for (int i = 0; i < visibleTiles.length; i++) ...[
                  Expanded(child: _Tile(tile: visibleTiles[i])),
                  if (i < visibleTiles.length - 1) const SizedBox(width: AppSizes.sm),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile});
  final CollectionTile tile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: NetworkImageBox(
              url: resolveImageUrl(tile.imageUrl),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tile.label,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
