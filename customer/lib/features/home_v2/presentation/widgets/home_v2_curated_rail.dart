import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_models.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class HomeV2CuratedRail extends StatelessWidget {
  const HomeV2CuratedRail({super.key, required this.item});
  final CuratedRailItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        height: 160,
        decoration: ShapeDecoration(
          color: item.bgColor,
          shape: AppShapes.squircle(AppSizes.radiusLg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              left: null,
              right: 0,
              child: SizedBox(
                width: 180,
                child: NetworkImageBox(
                  url: resolveImageUrl(item.imageUrl),
                  placeholderColor: item.bgColor,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      item.bgColor,
                      item.bgColor.withValues(alpha: 0.7),
                      item.bgColor.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.55, 0.85],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.eyebrow,
                    style: TextStyle(
                      color: item.accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 200,
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 200,
                    child: Text(
                      item.subtitle,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: 6,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.black,
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.cta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
