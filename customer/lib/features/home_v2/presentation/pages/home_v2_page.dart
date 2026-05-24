import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_mapper.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/tracking_service.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_ad_strip.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_brand_spotlight.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/categories_rail.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_collection_banner.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_curated_rail.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_flash_deals.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_footer_strip.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_hero_carousel.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_product_carousel.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/home_v2_recently_viewed.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.brand,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            Container(
              color: AppColors.brand,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: const [
                    HomeV2TopBar(),
                    HomeV2SearchBar(),
                    SizedBox(height: AppSizes.sm),
                  ],
                ),
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
      child: _HomeFeedList(feed: provider.feed),
    );
  }
}

/// Renders the home feed sections. Empty sections collapse silently
/// (each widget early-returns on empty input), so a backend with no
/// banners but live flash deals still produces a coherent page.
class _HomeFeedList extends StatefulWidget {
  const _HomeFeedList({required this.feed});
  final HomeFeed feed;

  @override
  State<_HomeFeedList> createState() => _HomeFeedListState();
}

class _HomeFeedListState extends State<_HomeFeedList> {
  /// Identity of the last feed snapshot we already fired impressions
  /// for. Prevents the impression burst from re-firing on every
  /// rebuild (e.g. when the cart badge changes higher in the tree).
  int? _trackedFeedHash;

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
    final hash = Object.hashAll([
      ...widget.feed.trending.take(20).map((p) => p.productId),
      ...widget.feed.recommended.take(20).map((p) => p.productId),
    ]);
    if (hash == _trackedFeedHash) return;
    _trackedFeedHash = hash;
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
    // Slice the curated rails into two for the inline placements; the
    // backend may return 0, 1, or many — index-safe access keeps the
    // layout stable.
    final rail0 = feed.curatedRails.isNotEmpty ? feed.curatedRails[0] : null;
    final rail1 = feed.curatedRails.length > 1 ? feed.curatedRails[1] : null;
    final collectionTitle =
        feed.collectionTiles.isNotEmpty ? feed.collectionTiles.first : null;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        // 1 — Browse intent: canonical category rail right under the
        // fold. Backed by CategoriesProvider (real taxonomy), not the
        // legacy sample-data pucks.
        const CategoriesRail(),

        // 2 — Trust: lower buying anxiety before showing prices.
        const HomeV2TrustStrip(),
        const SizedBox(height: AppSizes.lg),

        // 3 — Hero ads: editorial brand discovery, auto-rotating.
        HomeV2HeroCarousel(slides: feed.heroSlides),
        if (feed.heroSlides.isNotEmpty) const SizedBox(height: AppSizes.xl),

        // 4 — Urgency: live countdown + sold-progress pulls scroll.
        HomeV2FlashDeals(deals: feed.flashDeals),
        if (feed.flashDeals.isNotEmpty) const SizedBox(height: AppSizes.xl),

        // 5 — Sponsored brand strip — three medium-size ads.
        HomeV2AdStrip(ads: feed.adStrip),
        if (feed.adStrip.isNotEmpty) const SizedBox(height: AppSizes.xl),

        // 6 — Brand carousel: aspirational shopping for brand-led users.
        HomeV2BrandSpotlight(brands: feed.brandSpotlights),
        if (feed.brandSpotlights.isNotEmpty)
          const SizedBox(height: AppSizes.xl),

        // 7 — Personalised: for-you list lands here once the auth call
        //      resolves; falls back to trending for cold-start users.
        if (feed.recommended.isNotEmpty)
          HomeV2ProductCarousel(
            eyebrow: 'JUST FOR YOU',
            title: 'Picked for you',
            products: feed.recommended,
          )
        else if (feed.trending.isNotEmpty)
          HomeV2ProductCarousel(
            eyebrow: 'TRENDING NOW',
            title: 'Trending right now',
            products: feed.trending.take(10).toList(),
          ),
        const SizedBox(height: AppSizes.xl),

        // 9 — Editorial collection — lifestyle storytelling.
        if (rail0 != null) ...[
          HomeV2CuratedRail(item: rail0),
          const SizedBox(height: AppSizes.xl),
        ],

        // 10 — Social proof rail: trending overall.
        if (feed.trending.length > 5)
          HomeV2ProductCarousel(
            eyebrow: 'TRENDING NOW',
            title: 'Customers love these',
            products: feed.trending.skip(5).take(10).toList(),
          ),
        const SizedBox(height: AppSizes.xl),

        // 11 — Editorial collection — bundled tiles.
        if (collectionTitle != null)
          HomeV2CollectionBanner(
            tiles: feed.collectionTiles,
            title: collectionTitle.label,
          ),
        if (collectionTitle != null) const SizedBox(height: AppSizes.xl),

        // 12 — Second curated rail keeps depth interesting.
        if (rail1 != null) ...[
          HomeV2CuratedRail(item: rail1),
          const SizedBox(height: AppSizes.xl),
        ],

        // 13 — Re-engagement: "you were looking at this".
        HomeV2RecentlyViewed(items: feed.recentlyViewed),
        if (feed.recentlyViewed.isNotEmpty)
          const SizedBox(height: AppSizes.xl),

        // 14 — Trust footer: closes the page reassuring the buyer.
        const HomeV2FooterStrip(),
      ],
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
