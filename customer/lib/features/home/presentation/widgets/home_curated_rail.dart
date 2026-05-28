import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/banner_slide/presentation/pages/banner_slide_detail_page.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/hero_slide_templates.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';

/// Full-width templated card used by the composer's curated-rail slot.
/// Reuses `HeroSlideTemplateRenderer` so the rail honours the same
/// Classic/Minimal/Split/… layout the merchant authored — no separate
/// half-image-half-text card to maintain.
class HomeCuratedRail extends StatelessWidget {
  const HomeCuratedRail({super.key, required this.slide});
  final HeroSlide slide;

  void _onTap(BuildContext context) {
    final id = slide.bannerId;
    if (id != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BannerSlideDetailPage(bannerId: id)),
      );
      return;
    }
    // Collection-sourced rails arrive without a bannerId; fall back to a
    // search keyed off the ctaTarget's collection slug (`collection:foo`)
    // or, failing that, the rail's title.
    final target = slide.ctaTarget ?? '';
    final collectionSlug = target.startsWith('collection:')
        ? target.substring('collection:'.length)
        : null;
    final query = (collectionSlug != null && collectionSlug.isNotEmpty)
        ? collectionSlug
        : slide.title;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchPage(initialQuery: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - (AppSizes.sm * 2);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
          child: SizedBox(
            width: width,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onTap(context),
              child: HeroSlideTemplateRenderer(slide: slide),
            ),
          ),
        );
      },
    );
  }
}
