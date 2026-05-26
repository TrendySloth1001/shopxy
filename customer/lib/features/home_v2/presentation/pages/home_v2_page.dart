import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/home_v2/data/home_blocks.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_mapper.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/tracking_service.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_ad_strip.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_brand_spotlight.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/categories_rail.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_feed_blocks.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_flash_deals.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_footer_strip.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_hero_carousel.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_search_bar.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_top_bar.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_trust_strip.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

class HomeV2Page extends StatefulWidget {
  const HomeV2Page({super.key});

  @override
  State<HomeV2Page> createState() => _HomeV2PageState();
}

class _HomeV2PageState extends State<HomeV2Page> {
  @override
  void initState() {
    super.initState();
    // Provider boot already kicks off on app start; this guarantees a
    // refresh whenever the home tab is re-mounted after a long pause
    // (e.g. user came back to the app after an hour).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<HomeFeedProvider>();
      if (p.isInitial && !p.isLoading) p.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeFeedProvider>();
    // Canvas-on-canvas header — no coloured band any more. The status
    // bar reads as part of the page (dark icons on the warm parchment
    // background), and the top bar + search pill sit on the same
    // canvas surface as the feed below them.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: AppColors.canvas,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: const [
                  HomeV2TopBar(),
                  HomeV2SearchBar(),
                ],
              ),
            ),
            Expanded(child: _buildBody(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(HomeFeedProvider provider) {
    if (provider.status == HomeFeedStatus.error && provider.isInitial) {
      return _ErrorRetry(
        message: provider.error ?? 'Could not load home',
        onRetry: provider.refresh,
      );
    }
    if (provider.isInitial && provider.isLoading) {
      return const _HomeSkeleton();
    }
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: _HomeFeedList(
        feed: provider.feed,
        feedVersion: provider.feedVersion,
      ),
    );
  }
}

/// Renders the home feed sections. Empty sections collapse silently
/// (each widget early-returns on empty input), so a backend with no
/// banners but live flash deals still produces a coherent page.
class _HomeFeedList extends StatefulWidget {
  const _HomeFeedList({required this.feed, required this.feedVersion});
  final HomeFeed feed;

  /// Monotonic counter that ticks each time the provider successfully
  /// refreshes. We use this as the cache key for impression tracking
  /// so unrelated rebuilds (cart badge, theme changes) don't re-fire
  /// the impression batch.
  final int feedVersion;

  @override
  State<_HomeFeedList> createState() => _HomeFeedListState();
}

class _HomeFeedListState extends State<_HomeFeedList> {
  /// Version of the last feed snapshot we already fired impressions
  /// for. Prevents the impression burst from re-firing on every
  /// rebuild (e.g. when the cart badge changes higher in the tree).
  int? _trackedFeedVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackImpressions());
  }

  @override
  void didUpdateWidget(covariant _HomeFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackImpressions());
  }

  void _trackImpressions() {
    if (!mounted) return;
    if (widget.feedVersion == _trackedFeedVersion) return;
    _trackedFeedVersion = widget.feedVersion;
    final tracking = context.read<TrackingService>();
    // Server batches + dedupes on clientUuid, so a quick scroll-by
    // burst still stays cheap even if we fire a few extras.
    for (final p in widget.feed.trending.take(20)) {
      tracking.recordImpression(p.productId);
    }
    for (final p in widget.feed.recommended.take(20)) {
      tracking.recordImpression(p.productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;
    // Everything below the brand spotlight runs through the block
    // composer (lib/.../data/home_blocks.dart). The composer turns the
    // raw product slices into a varied, long-scroll feed (mosaic, grid,
    // reels, comparison, …) so we no longer have a parade of identical
    // horizontal carousels.
    final blocks = composeHomeBlocks(feed);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      // The fixed prelude (categories → trust → hero → flash → ad strip
      // → spotlight) plus one slot per composer block plus the footer.
      // Each section is gated by a `.isNotEmpty` check inside its widget
      // so empty payloads collapse without leaving stray gaps.
      itemCount: 6 + blocks.length + 1,
      itemBuilder: (context, i) {
        switch (i) {
          case 0:
            // Browse intent: canonical category rail right under the
            // fold. Backed by CategoriesProvider (real taxonomy), not
            // the legacy sample-data pucks.
            return const CategoriesRail();
          case 1:
            // Trust: lower buying anxiety before showing prices.
            return const Padding(
              padding: EdgeInsets.only(bottom: AppSizes.lg),
              child: HomeV2TrustStrip(),
            );
          case 2:
            // Hero ads: editorial brand discovery, auto-rotating.
            return Padding(
              padding: EdgeInsets.only(
                bottom: feed.heroSlides.isNotEmpty ? AppSizes.xl : 0,
              ),
              child: HomeV2HeroCarousel(slides: feed.heroSlides),
            );
          case 3:
            // Urgency: live countdown + sold-progress pulls scroll.
            return Padding(
              padding: EdgeInsets.only(
                bottom: feed.flashDeals.isNotEmpty ? AppSizes.xl : 0,
              ),
              child: HomeV2FlashDeals(deals: feed.flashDeals),
            );
          case 4:
            // Sponsored brand strip — three medium-size ads.
            return Padding(
              padding: EdgeInsets.only(
                bottom: feed.adStrip.isNotEmpty ? AppSizes.xl : 0,
              ),
              child: HomeV2AdStrip(ads: feed.adStrip),
            );
          case 5:
            // Brand carousel: aspirational shopping for brand-led users.
            return Padding(
              padding: EdgeInsets.only(
                bottom:
                    feed.brandSpotlights.isNotEmpty ? AppSizes.xl : 0,
              ),
              child: HomeV2BrandSpotlight(brands: feed.brandSpotlights),
            );
        }

        final blockIdx = i - 6;
        if (blockIdx < blocks.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.xl),
            child: HomeFeedBlock(block: blocks[blockIdx]),
          );
        }

        // Trust footer closes the page.
        return const HomeV2FooterStrip();
      },
    );
  }
}

/// Shimmer-free first-paint placeholder. Plain blocks keep the layout
/// height stable while the network call resolves; a flicker-free
/// transition from skeleton → real content matters more here than a
/// fancier animation.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block({double height = 120, EdgeInsets? margin}) => Container(
          margin:
              margin ?? const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          height: height,
          decoration: BoxDecoration(
            color: AppColors.heroPanel,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        );
    return ListView(
      padding: const EdgeInsets.only(top: AppSizes.lg, bottom: AppSizes.huge),
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.lg),
            itemBuilder: (_, _) => Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.heroPanel,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 8,
                  color: AppColors.heroPanel,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        block(height: 188),
        const SizedBox(height: AppSizes.xl),
        block(height: 232),
        const SizedBox(height: AppSizes.xl),
        block(height: 130),
        const SizedBox(height: AppSizes.xl),
        block(height: 280),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.md),
            const Text(
              "Couldn't load your home feed",
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
