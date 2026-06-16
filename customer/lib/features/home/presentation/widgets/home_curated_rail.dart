import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_banner_image.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';

/// Full-width curated banner image. Like every other banner placement
/// it's now just a plain tappable picture + optional link.
class HomeCuratedRail extends StatelessWidget {
  const HomeCuratedRail({super.key, required this.slide});
  final HeroSlide slide;

  // Wide banner strip aspect ratio.
  static const double _aspectRatio = 16 / 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - (AppSizes.sm * 2);
        final height = width / _aspectRatio;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
          child: SizedBox(
            width: width,
            height: height,
            child: HomeBannerImage(
              url: resolveImageUrl(slide.imageUrl),
              linkUrl: slide.linkUrl,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      },
    );
  }
}
