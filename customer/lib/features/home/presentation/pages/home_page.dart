import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/home/data/models/home_blocks.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home/presentation/services/tracking_service.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/categories_rail.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_feed_blocks.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_footer_strip.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_pending_invite_callout.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_product_carousel.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_recently_viewed.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_search_bar.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_top_bar.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_trust_strip.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
                children: [
                  const HomeTopBar(),
                  const HomeSearchBar(),
                  Container(
                    height: 0.6,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                    ),
                    color: AppColors.hairline,
                  ),
                  // Pinned above the scroll view so a pending invite is
                  // unmissable — the user can't scroll past it.
                  const HomePendingInviteCallout(),
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
        blocks: provider.blocks,
        isLoadingMore: provider.endlessLoading,
        isExhausted: provider.endlessExhausted,
        loadMore: provider.loadMore,
        endlessError: provider.endlessError,
      ),
    );
  }
}

/// Renders the home feed sections. Empty sections collapse silently
/// (each widget early-returns on empty input), so a backend with no
/// banners but live flash deals still produces a coherent page.
class _HomeFeedList extends StatefulWidget {
  const _HomeFeedList({
    required this.feed,
    required this.feedVersion,
    required this.blocks,
    required this.isLoadingMore,
    required this.isExhausted,
    required this.loadMore,
    required this.endlessError,
  });
  final HomeFeed feed;

  /// Monotonic counter that ticks each time the provider successfully
  /// refreshes. We use this as the cache key for impression tracking
  /// so unrelated rebuilds (cart badge, theme changes) don't re-fire
  /// the impression batch.
  final int feedVersion;

  /// Composed block list owned by the provider — grows as the endless
  /// pager fetches more pages.
  final List<HomeBlock> blocks;
  final bool isLoadingMore;
  final bool isExhausted;
  final String? endlessError;
  final Future<void> Function() loadMore;

  @override
  State<_HomeFeedList> createState() => _HomeFeedListState();
}

class _HomeFeedListState extends State<_HomeFeedList> {
  /// Version of the last feed snapshot we already fired impressions
  /// for. Prevents the impression burst from re-firing on every
  /// rebuild (e.g. when the cart badge changes higher in the tree).
  int? _trackedFeedVersion;
  final ScrollController _scroll = ScrollController();
  // Track how many blocks we'd already counted impressions for so a
  // newly-appended endless page only fires impressions for its own
  // products, not the entire growing list.
  int _impressionWatermark = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackImpressions());
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (widget.isExhausted || widget.isLoadingMore) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    // Fire when within ~1.5 screens of the bottom so the next page is
    // already on the wire by the time the user gets there.
    if (pos.pixels >= pos.maxScrollExtent - pos.viewportDimension * 1.5) {
      widget.loadMore();
    }
  }

  @override
  void didUpdateWidget(covariant _HomeFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A successful refresh resets blocks to a smaller list — drop the
    // watermark so post-refresh impressions fire from the start.
    if (widget.feedVersion != oldWidget.feedVersion) {
      _impressionWatermark = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackImpressions());
    // If new content arrived but the list is shorter than the
    // viewport the scroll listener never fires — kick the pager
    // manually until the page fills up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.maxScrollExtent <= 0 &&
          !widget.isLoadingMore &&
          !widget.isExhausted) {
        widget.loadMore();
      }
    });
  }

  void _trackImpressions() {
    if (!mounted) return;
    if (widget.feedVersion == _trackedFeedVersion &&
        _impressionWatermark >= widget.blocks.length) {
      return;
    }
    _trackedFeedVersion = widget.feedVersion;
    final tracking = context.read<TrackingService>();
    // Server batches + dedupes on clientUuid, so a quick scroll-by
    // burst still stays cheap even if we fire a few extras. We walk
    // only the newly-appended blocks since the last call.
    for (var i = _impressionWatermark; i < widget.blocks.length; i++) {
      for (final p in _productsInBlock(widget.blocks[i])) {
        tracking.recordImpression(p.productId);
      }
    }
    _impressionWatermark = widget.blocks.length;
  }

  Iterable<ProductCard> _productsInBlock(HomeBlock b) {
    return switch (b) {
      MosaicBlock m => [m.hero, m.topRight, m.bottomRight],
      Grid2ColBlock g => g.products,
      Grid3CompactBlock g => g.products,
      VerticalCardsBlock v => v.products,
      ReelsTallBlock r => r.products,
      CategoryCapsuleBlock c => c.products,
      QuickAddChipsBlock q => q.products,
      ComparisonBlock c => [c.left, c.right],
      CarouselBlock c => c.products,
      SponsoredCarouselBlock s => s.products,
      RecentlyViewedBlock r => r.products,
      // Non-product blocks (banners, curated rails, single promos)
      // are tracked as banner impressions elsewhere, not here.
      CuratedRailBlock _ => const <ProductCard>[],
      CollectionBannerBlock _ => const <ProductCard>[],
      HeroSingleBlock _ => const <ProductCard>[],
      AdSingleBlock _ => const <ProductCard>[],
      PromoSingleBlock _ => const <ProductCard>[],
      FlashSingleBlock _ => const <ProductCard>[],
      SpotlightSingleBlock _ => const <ProductCard>[],
      PosterProductBlock p => [p.product],
      LeaderboardBlock l => l.products,
      BrandFocusBlock f => f.products,
      PriceBandBlock p => p.products,
      ZigZagDuoBlock z => [z.hero, z.pair],
      ShopShowcaseBlock s => s.products,
    };
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.blocks;
    final feed = widget.feed;

    // Conditional prelude slots. Order matches the user's mental
    // model: browse intent (categories) → continuity (things they
    // viewed) → freshness (new arrivals) → then the endless cycle.
    // Empty slots collapse so the layout doesn't leave a hole.
    final preludeSlots = <Widget>[
      const CategoriesRail(),
      const Padding(
        padding: EdgeInsets.only(bottom: AppSizes.lg),
        child: HomeTrustStrip(),
      ),
      if (feed.recentlyViewed.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: HomeRecentlyViewed(items: feed.recentlyViewed),
        ),
      if (feed.newInStock.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: HomeProductCarousel(
            eyebrow: 'JUST LANDED',
            title: 'Fresh in stock',
            products: feed.newInStock,
          ),
        ),
    ];

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      // Prelude (variable, depending on which conditional slots have
      // data) + composed blocks + tail sentinel (loader / footer).
      itemCount: preludeSlots.length + blocks.length + 1,
      itemBuilder: (context, i) {
        if (i < preludeSlots.length) return preludeSlots[i];

        final blockIdx = i - preludeSlots.length;
        if (blockIdx < blocks.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.xl),
            child: HomeFeedBlock(block: blocks[blockIdx]),
          );
        }

        // Tail sentinel. Spinner only when a page is actually in
        // flight — the older `isLoadingMore || blocks.isNotEmpty`
        // gated wrong and kept the spinner glued on after every
        // successful page, making the feed look frozen.
        if (widget.isExhausted) {
          return _EndlessExhausted(
            message: widget.endlessError == null
                ? "You've reached the end — pull to refresh"
                : 'Took a breather to avoid rate limits — pull to refresh',
          );
        }
        if (widget.isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
            child: Center(
              child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          );
        }
        // Empty-state safety net: nothing loaded, nothing loading,
        // nothing exhausted — show the footer instead of a blank tile.
        if (blocks.isEmpty) return const HomeFooterStrip();
        // Idle tail between pages — let the scroll listener notice
        // we've passed the prefetch threshold and call loadMore.
        return const SizedBox(height: AppSizes.xl);
      },
    );
  }
}

class _EndlessExhausted extends StatelessWidget {
  const _EndlessExhausted({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.xl, AppSizes.lg, AppSizes.huge,
      ),
      child: Column(
        children: [
          const HomeFooterStrip(),
          const SizedBox(height: AppSizes.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ],
      ),
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
