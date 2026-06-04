import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/banner_slide/presentation/pages/banner_slide_detail_page.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/hero_slide_templates.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

class HomeHeroCarousel extends StatefulWidget {
  const HomeHeroCarousel({super.key, required this.slides});
  final List<HeroSlide> slides;

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  // Full-width pages: a fractional viewport leaks the next slide's bg
  // colour into the right margin and reads as a dead strip when the
  // adjacent slide is light. Symmetric breathing room comes from the
  // itemBuilder padding instead.
  final _controller = PageController();
  int _page = 0;
  Timer? _autoPlay;

  @override
  void initState() {
    super.initState();
    _autoPlay = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final count = widget.slides.length;
      if (count == 0) return;
      final next = (_page + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    if (slides.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        // PageView needs a definite height. Compute it from the
        // template card's aspect ratio so the carousel matches the
        // exact size each templated slide will render at — eliminates
        // the overflow that a hard-coded 188 used to cause.
        final cardWidth = constraints.maxWidth - (AppSizes.sm * 2);
        final pageHeight = cardWidth / HeroSlideTemplateRenderer.aspectRatio;
        return Column(
          children: [
            SizedBox(
              height: pageHeight,
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = slides[i];
                  final card = _HeroSlideCard(slide: slide);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                    child: slide.bannerId == null
                        ? card
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BannerSlideDetailPage(
                                  bannerId: slide.bannerId!,
                                ),
                              ),
                            ),
                            child: card,
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: AppDurations.searchDebounce,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: active ? 18 : 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.brand : AppColors.disabled,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

/// Renders one slide using the template the merchant picked.
class _HeroSlideCard extends StatelessWidget {
  const _HeroSlideCard({required this.slide});
  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HeroSlideTemplateRenderer(slide: slide),
        const Positioned(
          right: 6,
          bottom: 6,
          child: _AdBadge(),
        ),
      ],
    );
  }
}

/// Small "AD" affordance over the bottom-right of every hero slide so
/// the merchant's paid placement is disclosed to the shopper.
class _AdBadge extends StatelessWidget {
  const _AdBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'AD',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
