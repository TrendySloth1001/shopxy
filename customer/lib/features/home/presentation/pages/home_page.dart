import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home/presentation/services/tracking_service.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/categories_rail.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_ad_strip.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_curated_rail.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_footer_strip.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_pending_invite_callout.dart';
import 'package:shopxy_customer/features/home/presentation/pages/section_products_page.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_product_carousel.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_recently_viewed.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_search_bar.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_top_bar.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_trust_strip.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Owned here so both the scrollable feed AND the header can read
  /// the same offset. Header morphs between expanded ↔ collapsed
  /// based on `_shrink`, 0..1, derived from `_scroll.offset`.
  final ScrollController _scroll = ScrollController();
  double _shrink = 0.0;

  /// Pixels of scroll required to fully collapse the header. Smaller
  /// = snappier collapse; larger = lazier. 80 lands near the natural
  /// "I started scrolling" feel.
  static const double _collapseDistance = 80;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
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
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final next = (_scroll.offset / _collapseDistance).clamp(0.0, 1.0);
    if ((next - _shrink).abs() < 0.01) return;
    setState(() => _shrink = next);
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
                  HomeTopBar(shrink: _shrink),
                  HomeSearchBar(shrink: _shrink),
                  Container(
                    height: 0.6,
                    margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                    color: AppColors.hairline,
                  ),
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
      // The pending-payment affordance lives in the top bar (a wallet
      // icon + badge next to the bell) so the feed stays a clean
      // shopping surface — see HomeTopBar.
      child: _HomeFeedList(
        feed: provider.feed,
        feedVersion: provider.feedVersion,
        products: provider.products,
        isLoadingMore: provider.endlessLoading,
        isExhausted: provider.endlessExhausted,
        loadMore: provider.loadMore,
        endlessError: provider.endlessError,
        scroll: _scroll,
      ),
    );
  }
}

/// Renders the home feed: category pucks, banners, product rails, then
/// an endless product grid. Empty sections collapse silently (each
/// widget early-returns on empty input) so a backend with no banners
/// but live trending still produces a coherent page.
class _HomeFeedList extends StatefulWidget {
  const _HomeFeedList({
    required this.feed,
    required this.feedVersion,
    required this.products,
    required this.isLoadingMore,
    required this.isExhausted,
    required this.loadMore,
    required this.endlessError,
    required this.scroll,
  });
  final HomeFeed feed;
  final ScrollController scroll;

  /// Monotonic counter that ticks each time the provider successfully
  /// refreshes. We use this as the cache key for impression tracking
  /// so unrelated rebuilds (cart badge, theme changes) don't re-fire
  /// the impression batch.
  final int feedVersion;

  /// Flat product list owned by the provider — grows as the endless
  /// pager fetches more pages. Rendered as a 2-column grid.
  final List<ProductCard> products;
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
  // Track how many grid products we'd already counted impressions for
  // so a newly-appended page only fires impressions for its own
  // products, not the entire growing list.
  int _impressionWatermark = 0;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackImpressions());
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_maybeLoadMore);
    super.dispose();
  }

  void _maybeLoadMore() {
    if (widget.isExhausted || widget.isLoadingMore) return;
    if (!widget.scroll.hasClients) return;
    final pos = widget.scroll.position;
    // Fire when within ~1.5 screens of the bottom so the next page is
    // already on the wire by the time the user gets there.
    if (pos.pixels >= pos.maxScrollExtent - pos.viewportDimension * 1.5) {
      widget.loadMore();
    }
  }

  @override
  void didUpdateWidget(covariant _HomeFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A successful refresh resets products to a smaller list — drop the
    // watermark so post-refresh impressions fire from the start.
    if (widget.feedVersion != oldWidget.feedVersion) {
      _impressionWatermark = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackImpressions());
    // If new content arrived but the list is shorter than the viewport
    // the scroll listener never fires — kick the pager manually until
    // the page fills up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.scroll.hasClients) return;
      final pos = widget.scroll.position;
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
        _impressionWatermark >= widget.products.length) {
      return;
    }
    _trackedFeedVersion = widget.feedVersion;
    final tracking = context.read<TrackingService>();
    // Server batches + dedupes on clientUuid, so a quick scroll-by
    // burst still stays cheap even if we fire a few extras. We walk
    // only the newly-appended products since the last call.
    for (var i = _impressionWatermark; i < widget.products.length; i++) {
      tracking.recordImpression(widget.products[i].productId);
    }
    _impressionWatermark = widget.products.length;
  }

  @override
  Widget build(BuildContext context) {
    final feed = widget.feed;

    // Section slots above the endless grid. Order matches the user's
    // mental model: browse intent (categories) → marketing (hero) →
    // trust → continuity (recently viewed) → freshness → trending →
    // curated banners → then the endless grid. Empty slots collapse.
    final sections = <Widget>[
      const HomePendingInviteCallout(),
      const CategoriesRail(),
      if (feed.heroSlides.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: HomeHeroCarousel(slides: feed.heroSlides),
        ),
      const Padding(
        padding: EdgeInsets.only(bottom: AppSizes.lg),
        child: HomeTrustStrip(),
      ),
      if (feed.recentlyViewed.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: HomeRecentlyViewed(items: feed.recentlyViewed),
        ),
      if (feed.adStrip.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: HomeAdStrip(slides: feed.adStrip),
        ),
      if (feed.newInStock.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: _ProductRail(
            eyebrow: 'JUST LANDED',
            title: 'Fresh in stock',
            products: feed.newInStock,
          ),
        ),
      if (feed.promoBanners.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: HomeAdStrip(slides: feed.promoBanners),
        ),
      if (feed.trending.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: _ProductRail(
            eyebrow: 'TRENDING NOW',
            title: 'Popular right now',
            products: feed.trending,
          ),
        ),
      for (final slide in feed.curatedRails)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xl),
          child: HomeCuratedRail(slide: slide),
        ),
    ];

    final products = widget.products;
    // 2-column product grid laid out manually (rows of two) inside the
    // single scroll view so it shares the page's scroll controller.
    final gridRows = (products.length / 2).ceil();

    return CustomScrollView(
      controller: widget.scroll,
      slivers: [
        SliverList(delegate: SliverChildListDelegate(sections)),
        if (products.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, row) {
                final left = products[row * 2];
                final rightIdx = row * 2 + 1;
                final right = rightIdx < products.length
                    ? products[rightIdx]
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: HomeProductTile(product: left, width: null),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: right == null
                            ? const SizedBox.shrink()
                            : HomeProductTile(product: right, width: null),
                      ),
                    ],
                  ),
                );
              }, childCount: gridRows),
            ),
          ),
        SliverToBoxAdapter(child: _tail()),
      ],
    );
  }

  Widget _tail() {
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
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    // Nothing loading / loaded / exhausted — show the footer.
    if (widget.products.isEmpty) return const HomeFooterStrip();
    return const SizedBox(height: AppSizes.xl);
  }
}

/// Thin wrapper that gives a product carousel a "see all" target.
class _ProductRail extends StatelessWidget {
  const _ProductRail({
    required this.eyebrow,
    required this.title,
    required this.products,
  });
  final String eyebrow;
  final String title;
  final List<ProductCard> products;

  @override
  Widget build(BuildContext context) {
    return HomeProductCarousel(
      eyebrow: eyebrow,
      title: title,
      products: products,
      onSeeAll: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SectionProductsPage(
            eyebrow: eyebrow,
            title: title,
            products: products,
          ),
        ),
      ),
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
        AppSizes.lg,
        AppSizes.xl,
        AppSizes.lg,
        AppSizes.huge,
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
      margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSizes.lg),
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
                Container(width: 40, height: 8, color: AppColors.heroPanel),
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
            const AppIcon(
              AppIcons.cloudOffOutlined,
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
              icon: const AppIcon(AppIcons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
