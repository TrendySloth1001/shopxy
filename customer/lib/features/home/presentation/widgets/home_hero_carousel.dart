import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_banner_image.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Full-width banner carousel. Each slide is now just a plain tappable
/// image (see [HomeBannerImage]) — the templated card system is gone.
class HomeHeroCarousel extends StatefulWidget {
  const HomeHeroCarousel({super.key, required this.slides});
  final List<HeroSlide> slides;

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  // Full-width pages: a fractional viewport leaks the next slide into
  // the right margin and reads as a dead strip. Symmetric breathing
  // room comes from the itemBuilder padding instead.
  final _controller = PageController();
  int _page = 0;
  Timer? _autoPlay;

  // Banner aspect ratio — a wide marketing strip. Drives the carousel's
  // definite height so the PageView never overflows.
  static const double _aspectRatio = 16 / 7;

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
        final cardWidth = constraints.maxWidth - (AppSizes.sm * 2);
        final pageHeight = cardWidth / _aspectRatio;
        return Column(
          children: [
            SizedBox(
              height: pageHeight,
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                  child: HomeBannerImage(
                    url: resolveImageUrl(slides[i].imageUrl),
                    bannerId: slides[i].id,
                    linkUrl: slides[i].linkUrl,
                    productCount: slides[i].productCount,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
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
