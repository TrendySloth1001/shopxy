import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_banner_image.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';

/// Vertical stack of full-width banner images. Each banner is just a
/// plain tappable picture + optional link. Powers both the ad-strip and
/// promo-banner home slots — they share the same data shape and widget.
class HomeAdStrip extends StatelessWidget {
  const HomeAdStrip({super.key, required this.slides});
  final List<HeroSlide> slides;

  // Wide banner strip aspect ratio.
  static const double _aspectRatio = 16 / 6;

  @override
  Widget build(BuildContext context) {
    if (slides.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - (AppSizes.sm * 2);
        final height = width / _aspectRatio;
        return Column(
          children: [
            for (var i = 0; i < slides.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSizes.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: HomeBannerImage(
                    url: resolveImageUrl(slides[i].imageUrl),
                    bannerId: slides[i].id,
                    linkUrl: slides[i].linkUrl,
                    productCount: slides[i].productCount,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
