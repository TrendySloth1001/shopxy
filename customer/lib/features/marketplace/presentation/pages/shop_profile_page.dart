import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/core/share/share_service.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_shop.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

/// Public shop landing page. Reached from any "brand" tap — brand
/// spotlight cards, sponsored product rails, and the PDP "Visit shop"
/// link. Calls `/marketplace/shops/:slug/products` once on mount and
/// renders shop chrome + a product grid with pagination.
class ShopProfilePage extends StatefulWidget {
  const ShopProfilePage({super.key, required this.slug});
  final String slug;

  @override
  State<ShopProfilePage> createState() => _ShopProfilePageState();
}

class _ShopProfilePageState extends State<ShopProfilePage> {
  /// Page size — small enough that the first paint is fast on slow
  /// networks, large enough that scrolling past the visible viewport
  /// triggers the next page once.
  static const int _pageSize = 24;

  MarketplaceShop? _shop;
  final List<MarketplaceProduct> _products = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _sort = 'popular';
  int _page = 1;
  int _total = 0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstPage());
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_loadingMore || _loading || !_hasMore) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
      _products.clear();
      _page = 1;
      _hasMore = true;
    });
    try {
      final ds = context.read<MarketplaceRemoteDataSource>();
      final result = await ds.shopProducts(
        widget.slug,
        sort: _sort,
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _shop = result.shop;
        _products.addAll(result.products);
        _total = result.total;
        _hasMore = _products.length < _total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final ds = context.read<MarketplaceRemoteDataSource>();
      final nextPage = _page + 1;
      final result = await ds.shopProducts(
        widget.slug,
        sort: _sort,
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _products.addAll(result.products);
        _hasMore = _products.length < _total;
      });
    } catch (_) {
      // Silent on incremental load failure — the retry button on the
      // top-level error state covers full failures; a paginate hiccup
      // shouldn't blow away what's already on screen.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: _loading && _shop == null
            ? const _ShopProfileSkeleton()
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _loadFirstPage)
                : _Body(
                    shop: _shop!,
                    products: _products,
                    total: _total,
                    sort: _sort,
                    scrollController: _scroll,
                    loadingMore: _loadingMore,
                    hasMore: _hasMore,
                    onSort: (s) {
                      setState(() => _sort = s);
                      _loadFirstPage();
                    },
                  ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.shop,
    required this.products,
    required this.total,
    required this.sort,
    required this.onSort,
    required this.scrollController,
    required this.loadingMore,
    required this.hasMore,
  });
  final MarketplaceShop shop;
  final List<MarketplaceProduct> products;
  final int total;
  final String sort;
  final ValueChanged<String> onSort;
  final ScrollController scrollController;
  final bool loadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.black,
          expandedHeight: 200,
          pinned: true,
          actions: [
            Builder(builder: (ctx) {
              return IconButton(
                tooltip: 'Share shop',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () {
                  final box = ctx.findRenderObject() as RenderBox?;
                  const ShareService().shareShop(
                    slug: shop.slug,
                    name: shop.name,
                    originBox: box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null,
                  );
                },
              );
            }),
            const SizedBox(width: AppSizes.xs),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (shop.bannerUrl != null)
                  NetworkImageBox(url: resolveImageUrl(shop.bannerUrl!))
                else
                  Container(color: AppColors.heroPanel),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            shop.name,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shop.logoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: SizedBox(
                      width: 56, height: 56,
                      child: NetworkImageBox(url: resolveImageUrl(shop.logoUrl!)),
                    ),
                  )
                else
                  Container(
                    width: 56, height: 56,
                    decoration: ShapeDecoration(
                      color: AppColors.brandSoft,
                      shape: AppShapes.squircle(AppSizes.radiusSm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      shop.name.isEmpty ? '?' : shop.name[0].toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                    ),
                  ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              shop.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                            ),
                          ),
                          if (shop.isVerified) ...[
                            const SizedBox(width: AppSizes.sm),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.info,
                              size: AppSizes.iconSm,
                            ),
                          ],
                        ],
                      ),
                      if (shop.tagline != null && shop.tagline!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSizes.xs),
                          child: Text(
                            shop.tagline!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      const SizedBox(height: AppSizes.sm),
                      Wrap(
                        spacing: AppSizes.md,
                        runSpacing: AppSizes.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (shop.rating != null)
                            _InlineStat(
                              icon: Icons.star_rounded,
                              iconColor: AppColors.success,
                              label:
                                  '${shop.rating!.toStringAsFixed(1)} (${shop.ratingCount})',
                              labelColor: AppColors.black,
                            ),
                          _InlineStat(
                            icon: Icons.shopping_bag_outlined,
                            iconColor: AppColors.muted,
                            label: '$total products',
                          ),
                          if (shop.locationLabel != null)
                            _InlineStat(
                              icon: Icons.place_outlined,
                              iconColor: AppColors.muted,
                              label: shop.locationLabel!,
                            ),
                          if (shop.joinedAt != null)
                            _InlineStat(
                              icon: Icons.calendar_today_outlined,
                              iconColor: AppColors.muted,
                              label:
                                  'Since ${DateFormat.yMMM().format(shop.joinedAt!)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in const [
                    ('popular', 'Popular'),
                    ('newest', 'Newest'),
                    ('price_asc', 'Price ↑'),
                    ('price_desc', 'Price ↓'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSizes.sm),
                      child: ChoiceChip(
                        label: Text(s.$2),
                        selected: sort == s.$1,
                        onSelected: (_) => onSort(s.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (shop.vacationMode)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg, 0, AppSizes.lg, AppSizes.sm),
              child: _VacationBanner(
                message: shop.vacationMessage ??
                    'This shop is on vacation. New orders are paused.',
              ),
            ),
          ),
        if (shop.returnPolicy != null ||
            shop.shippingPolicy != null ||
            shop.refundPolicy != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg, 0, AppSizes.lg, AppSizes.sm),
              child: _PoliciesCard(shop: shop),
            ),
          ),
        if (products.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: Text(
                  'No products published yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.sm),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSizes.md,
                mainAxisSpacing: AppSizes.md,
                childAspectRatio: 0.65,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ProductTile(product: products[i]),
                childCount: products.length,
              ),
            ),
          ),
          if (loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (!hasMore && products.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.xl),
                child: Center(
                  child: Text(
                    "You've reached the end.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xl)),
        ],
      ],
    );
  }
}

class _VacationBanner extends StatelessWidget {
  const _VacationBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warningSoft,
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.beach_access_rounded, color: AppColors.warning),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On vacation',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.black,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: AppSizes.iconSm),
        const SizedBox(width: AppSizes.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: labelColor ?? AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

/// Pill row that opens a bottom-sheet with the shop's return /
/// shipping / refund policies. Only the policies that have content
/// render as pills — keeps the row tight when the merchant has
/// filled in only one.
class _PoliciesCard extends StatelessWidget {
  const _PoliciesCard({required this.shop});
  final MarketplaceShop shop;

  void _openPolicies(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (_) => _PoliciesSheet(shop: shop),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pills = <_PolicyPillSpec>[
      if (shop.returnPolicy?.isNotEmpty == true)
        const _PolicyPillSpec(
            icon: Icons.assignment_return_outlined, label: 'Returns'),
      if (shop.shippingPolicy?.isNotEmpty == true)
        const _PolicyPillSpec(
            icon: Icons.local_shipping_outlined, label: 'Shipping'),
      if (shop.refundPolicy?.isNotEmpty == true)
        const _PolicyPillSpec(
            icon: Icons.currency_rupee_rounded, label: 'Refund'),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        onTap: () => _openPolicies(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  color: AppColors.brandStrong, size: AppSizes.iconMd),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shop policies',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.black,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: AppSizes.xs,
                      children: [
                        for (final p in pills)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.sm, vertical: AppSizes.xs),
                            decoration: ShapeDecoration(
                              color: AppColors.brandSoft,
                              shape: AppShapes.squircle(AppSizes.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(p.icon,
                                    size: 12, color: AppColors.brandStrong),
                                const SizedBox(width: AppSizes.xs),
                                Text(
                                  p.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.brandStrong,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyPillSpec {
  const _PolicyPillSpec({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _PoliciesSheet extends StatelessWidget {
  const _PoliciesSheet({required this.shop});
  final MarketplaceShop shop;
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.lg),
        child: ListView(
          controller: scrollController,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${shop.name} policies',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            if (shop.returnPolicy?.isNotEmpty == true)
              _PolicyBlock(
                title: 'Returns',
                icon: Icons.assignment_return_outlined,
                body: shop.returnPolicy!,
              ),
            if (shop.shippingPolicy?.isNotEmpty == true)
              _PolicyBlock(
                title: 'Shipping',
                icon: Icons.local_shipping_outlined,
                body: shop.shippingPolicy!,
              ),
            if (shop.refundPolicy?.isNotEmpty == true)
              _PolicyBlock(
                title: 'Refunds',
                icon: Icons.currency_rupee_rounded,
                body: shop.refundPolicy!,
              ),
          ],
        ),
      ),
    );
  }
}

class _PolicyBlock extends StatelessWidget {
  const _PolicyBlock({
    required this.title,
    required this.icon,
    required this.body,
  });
  final String title;
  final IconData icon;
  final String body;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSizes.iconSm, color: AppColors.brandStrong),
              const SizedBox(width: AppSizes.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.brandStrong,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.black,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});
  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    final image = product.images.isEmpty ? '' : product.images.first;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: product.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Container(
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                ),
                child: image.isEmpty
                    ? const Icon(Icons.image_outlined, color: AppColors.muted)
                    : NetworkImageBox(url: resolveImageUrl(image)),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppFormat.rupees(product.sellingPrice),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: AppSizes.xs),
              if (product.isDiscounted)
                Text(
                  AppFormat.rupees(product.mrp),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
              const SizedBox(width: AppSizes.xs),
              if (product.isDiscounted)
                Text(
                  '${product.discountPct}% off',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
          if (product.ratingAvg != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xs),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.success, size: 12),
                  const SizedBox(width: AppSizes.xs),
                  Text(
                    '${product.ratingAvg!.toStringAsFixed(1)} (${product.ratingCount})',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton / shimmer loading state
// ---------------------------------------------------------------------------

/// Full-page skeleton that mirrors the real layout: SliverAppBar (banner +
/// title area), shop-info row (logo + name + stats), sort-chips row, and a
/// 2-column product grid with 6 shimmer tiles.
class _ShopProfileSkeleton extends StatelessWidget {
  const _ShopProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // ── Banner (SliverAppBar stand-in) ──────────────────────────────
        SliverToBoxAdapter(
          child: AppShimmerBox(
            width: double.infinity,
            height: 200,
            radius: 0,
          ),
        ),
        // ── Shop-info row ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                AppShimmerBox(
                  width: 56,
                  height: 56,
                  radius: AppSizes.radiusSm,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop name
                      const AppShimmerLine(widthFactor: 0.55, height: 18),
                      const SizedBox(height: AppSizes.xs),
                      // Tagline
                      const AppShimmerLine(widthFactor: 0.75, height: 12),
                      const SizedBox(height: AppSizes.sm),
                      // Stat chips row
                      Row(
                        children: const [
                          AppShimmerLine(widthFactor: 0.22, height: 12),
                          SizedBox(width: AppSizes.md),
                          AppShimmerLine(widthFactor: 0.22, height: 12),
                          SizedBox(width: AppSizes.md),
                          AppShimmerLine(widthFactor: 0.18, height: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Sort chips row ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg, vertical: AppSizes.sm),
            child: Row(
              children: [
                for (final w in const [72.0, 64.0, 68.0, 72.0]) ...[
                  AppShimmerBox(width: w, height: 32, radius: AppSizes.radiusFull),
                  const SizedBox(width: AppSizes.sm),
                ],
              ],
            ),
          ),
        ),
        // ── Product grid skeleton (6 tiles) ──────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.xl),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSizes.md,
              mainAxisSpacing: AppSizes.md,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => const _ProductTileSkeleton(),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}

/// Single skeleton cell that mirrors _ProductTile:
/// square image placeholder + two text lines + a price line.
class _ProductTileSkeleton extends StatelessWidget {
  const _ProductTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Square image block
        AspectRatio(
          aspectRatio: 1,
          child: AppShimmerBox(
            width: double.infinity,
            height: double.infinity,
            radius: AppSizes.radiusMd,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        // Product name — two lines
        const AppShimmerLine(widthFactor: 0.9, height: 12),
        const SizedBox(height: AppSizes.xs),
        const AppShimmerLine(widthFactor: 0.65, height: 12),
        const SizedBox(height: AppSizes.xs),
        // Price line
        const AppShimmerLine(widthFactor: 0.45, height: 14),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.xl),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off_rounded,
            size: AppSizes.iconHuge, color: AppColors.muted),
        const SizedBox(height: AppSizes.md),
        Center(
          child: Text(
            "Couldn't load this shop",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Center(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Center(
          child: TextButton(onPressed: onRetry, child: const Text('Try again')),
        ),
      ],
    );
  }
}
