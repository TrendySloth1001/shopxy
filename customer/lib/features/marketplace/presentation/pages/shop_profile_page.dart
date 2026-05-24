import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_shop.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_v2_page.dart';
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
  MarketplaceShop? _shop;
  List<MarketplaceProduct> _products = const [];
  bool _loading = true;
  String? _error;
  String _sort = 'popular';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<MarketplaceRemoteDataSource>();
      final result = await ds.shopProducts(widget.slug, sort: _sort, limit: 60);
      if (!mounted) return;
      setState(() {
        _shop = result.shop;
        _products = result.products;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _shop == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _Body(
                    shop: _shop!,
                    products: _products,
                    sort: _sort,
                    onSort: (s) {
                      setState(() => _sort = s);
                      _load();
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
    required this.sort,
    required this.onSort,
  });
  final MarketplaceShop shop;
  final List<MarketplaceProduct> products;
  final String sort;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.black,
          expandedHeight: 200,
          pinned: true,
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
                      Text(
                        shop.name,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
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
                      Row(
                        children: [
                          if (shop.rating != null) ...[
                            const Icon(Icons.star_rounded, color: AppColors.success, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              '${shop.rating!.toStringAsFixed(1)} (${shop.ratingCount})',
                              style: const TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            '${products.length} products',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
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
        else
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
                (context, i) => _ProductTile(product: products[i]),
                childCount: products.length,
              ),
            ),
          ),
      ],
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
          builder: (_) => ProductDetailV2Page(productId: product.id),
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
