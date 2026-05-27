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
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
            ? const Center(child: CircularProgressIndicator())
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
            const SizedBox(width: 4),
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
          title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w800)),
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
                      style: const TextStyle(
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
                              style: const TextStyle(
                                color: AppColors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (shop.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.info,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      if (shop.tagline != null && shop.tagline!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            shop.tagline!,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
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
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.xl),
                child: Text(
                  'No products published yet.',
                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.xl),
                child: Center(
                  child: Text(
                    "You've reached the end.",
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: labelColor ?? AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
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
                  color: AppColors.brandStrong, size: 18),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shop policies',
                      style: TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final p in pills)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: ShapeDecoration(
                              color: AppColors.brandSoft,
                              shape: AppShapes.squircle(AppSizes.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(p.icon,
                                    size: 12, color: AppColors.brandStrong),
                                const SizedBox(width: 3),
                                Text(
                                  p.label,
                                  style: const TextStyle(
                                    color: AppColors.brandStrong,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
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
                    style: const TextStyle(
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
              Icon(icon, size: 16, color: AppColors.brandStrong),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.brandStrong,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 13.5,
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
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${product.sellingPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              if (product.isDiscounted)
                Text(
                  '₹${product.mrp.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              const SizedBox(width: 4),
              if (product.isDiscounted)
                Text(
                  '${product.discountPct}% off',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (product.ratingAvg != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.success, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '${product.ratingAvg!.toStringAsFixed(1)} (${product.ratingCount})',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
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
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.muted),
        const SizedBox(height: AppSizes.md),
        const Center(
          child: Text(
            "Couldn't load this shop",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.muted),
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
