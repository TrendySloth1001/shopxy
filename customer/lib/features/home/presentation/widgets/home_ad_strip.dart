import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/banner_slide/presentation/pages/banner_slide_detail_page.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/hero_slide_templates.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';

/// Vertical stack of full-width banner cards rendered with the same
/// `HeroSlideTemplateRenderer` the hero carousel uses — so the
/// Classic/Minimal/Split/… template the merchant picked in the slide
/// editor shows up here exactly the way the preview promised.
///
/// Powers two home slots: `case 4` (ad strip) and `case 6` (promo
/// banners). Both placements share the same data shape on the backend
/// and the same widget here.
class HomeAdStrip extends StatelessWidget {
  const HomeAdStrip({super.key, required this.slides});
  final List<HeroSlide> slides;

  @override
  Widget build(BuildContext context) {
    if (slides.isEmpty) return const SizedBox.shrink();
    // LayoutBuilder hands each card a tight width: HeroSlideTemplateRenderer
    // uses FractionallySizedBox internally, which needs bounded
    // horizontal constraints. The Column alone wouldn't bound width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - (AppSizes.sm * 2);
        return Column(
          children: [
            for (var i = 0; i < slides.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSizes.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                child: SizedBox(
                  width: width,
                  child: _BannerSlideCard(slide: slides[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BannerSlideCard extends StatelessWidget {
  const _BannerSlideCard({required this.slide});
  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    final card = HeroSlideTemplateRenderer(slide: slide);
    if (slide.bannerId == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BannerSlideDetailPage(bannerId: slide.bannerId!),
        ),
      ),
      child: card,
    );
  }
}
