import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

/// Paginated product feed for a single canonical category. Backend
/// rolls children up under the parent slug, so picking "Electronics"
/// shows laptops, cameras and headphones in one stream.
class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({super.key, required this.category});
  final Category category;

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final _scrollController = ScrollController();
  String _sort = 'popular';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<MarketplaceProduct> _products = const [];
  int _total = 0;
  int _page = 1;
  static const _limit = 24;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _products.length < _total) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    final ds = context.read<CategoriesRemoteDataSource>();
    setState(() {
      if (reset) {
        _isLoading = true;
        _page = 1;
      } else {
        _isLoadingMore = true;
        _page += 1;
      }
      _error = null;
    });
    try {
      final result = await ds.categoryProducts(
        widget.category.slug,
        page: reset ? 1 : _page,
        limit: _limit,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _products = reset
            ? result.products
            : [..._products, ...result.products];
        _total = result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (v) {
              setState(() => _sort = v);
              _load(reset: true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'popular', child: Text('Popular')),
              PopupMenuItem(value: 'newest', child: Text('Newest')),
              PopupMenuItem(value: 'price_asc', child: Text('Price: low to high')),
              PopupMenuItem(value: 'price_desc', child: Text('Price: high to low')),
            ],
          ),
        ],
      ),
      body: _isLoading && _products.isEmpty
          ? const _CategoryProductsSkeleton()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xxl),
                    child: Text(_error!, style: theme.textTheme.bodyMedium),
                  ),
                )
              : _products.isEmpty
                  ? const Center(
                      child: Text('No products in this category yet'),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      color: AppColors.black,
                      backgroundColor: AppColors.white,
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSizes.md),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSizes.lg,
                          crossAxisSpacing: AppSizes.md,
                          childAspectRatio: 0.66,
                        ),
                        itemCount:
                            _products.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _products.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSizes.lg),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return _ProductTile(
                            product: _products[index],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailPage(
                                  productId: _products[index].id,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets
// ---------------------------------------------------------------------------

/// Full-page skeleton that mirrors the 2-column product grid.
class _CategoryProductsSkeleton extends StatelessWidget {
  const _CategoryProductsSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSizes.lg,
        crossAxisSpacing: AppSizes.md,
        childAspectRatio: 0.66,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const _ProductTileSkeleton(),
    );
  }
}

/// Single skeleton tile mirroring _ProductTile layout.
class _ProductTileSkeleton extends StatelessWidget {
  const _ProductTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image area — 1:1
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
        AppShimmerLine(widthFactor: 0.9, height: 12),
        const SizedBox(height: AppSizes.xs),
        AppShimmerLine(widthFactor: 0.65, height: 12),
        const Spacer(),
        // Price row
        Row(
          children: [
            AppShimmerLine(widthFactor: 0.4, height: 14),
            const SizedBox(width: AppSizes.sm),
            AppShimmerLine(widthFactor: 0.3, height: 11),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final MarketplaceProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hero = product.images.isNotEmpty ? product.images.first : null;
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
              child: hero == null
                  ? Container(color: AppColors.surfaceTint)
                  : Image.network(
                      resolveImageUrl(hero),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: AppColors.surfaceTint),
                    ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            product.name,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            children: [
              Text(
                '₹${product.sellingPrice.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (product.isDiscounted) ...[
                const SizedBox(width: AppSizes.sm),
                Text(
                  '₹${product.mrp.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: AppSizes.xs),
                Text(
                  '${product.discountPct}% off',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
