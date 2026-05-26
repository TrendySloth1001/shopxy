import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/cart/presentation/pages/cart_page.dart';
import 'package:shopxy_customer/features/home/presentation/services/tracking_service.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/features/wishlist/presentation/widgets/wishlist_heart_button.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// The V2 product detail screen. Was a static mock until this build —
/// now talks to `GET /marketplace/products/:id` and renders gallery,
/// price + flash-sale state, rating histogram (best-effort using
/// denormed counts), tags-as-highlights, shop attribution, and wires
/// the bottom action bar to the real cart provider.
///
/// Fields the static design carried that the schema doesn't model yet
/// (variants, storage tiers, bank offers, full spec sheet) are simply
/// not rendered — the section collapses rather than showing fake data.
/// They'll come back when the merchant editor + Product schema are
/// expanded in the next slice.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  MarketplaceProduct? _product;
  bool _loading = true;
  String? _error;
  final PageController _gallery = PageController();
  int _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      // Fire VIEW event so recommendations / recently-viewed update.
      context.read<TrackingService>().recordView(widget.productId);
    });
  }

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<MarketplaceRemoteDataSource>();
      final p = await ds.product(widget.productId);
      if (!mounted) return;
      setState(() => _product = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addToCart() {
    final p = _product;
    if (p == null) return;
    // Bridge MarketplaceProduct → CatalogProduct so we can reuse the
    // existing CartProvider without rebuilding the cart model.
    final cp = CatalogProduct(
      id: p.id,
      name: p.name,
      sku: p.sku,
      unit: p.unit,
      sellingPrice: p.effectivePrice,
      mrp: p.mrp,
      taxPercent: p.taxPercent,
      stockQuantity: p.stockQuantity,
      imageUrl: p.images.isEmpty ? null : p.images.first,
      description: p.description,
      // Carry the owning shop forward so the cart can group by shopId
      // and the checkout can fire one POST per shop.
      shopId: p.shop?.id,
      shopName: p.shop?.name,
      shopSlug: p.shop?.slug,
    );
    final result = context.read<CartProvider>().add(cp);
    if (result == AddToCartResult.outOfStock) {
      showAppSnackbar(
        context,
        message: 'Out of stock',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    context.read<TrackingService>().recordAddToCart(p.id);
    showAppSnackbar(
      context,
      message: result == AddToCartResult.capped
          ? 'Reached the maximum we can deliver — added what we can.'
          : 'Added to cart',
      tone: AppSnackbarTone.success,
      actionLabel: 'View cart',
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CartPage()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: _loading && _product == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _Body(
                  product: _product!,
                  galleryController: _gallery,
                  galleryIndex: _galleryIndex,
                  onGalleryChanged: (i) => setState(() => _galleryIndex = i),
                ),
      bottomNavigationBar: _product == null ? null : _ActionBar(onAdd: _addToCart),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.product,
    required this.galleryController,
    required this.galleryIndex,
    required this.onGalleryChanged,
  });
  final MarketplaceProduct product;
  final PageController galleryController;
  final int galleryIndex;
  final ValueChanged<int> onGalleryChanged;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.black,
          pinned: true,
          actions: [
            WishlistHeartButton.flat(productId: product.id),
            const SizedBox(width: AppSizes.sm),
          ],
        ),
        SliverToBoxAdapter(
          child: _Gallery(
            urls: product.images,
            controller: galleryController,
            index: galleryIndex,
            onChanged: onGalleryChanged,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.shop != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ShopProfilePage(slug: product.shop!.slug),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          product.shop!.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.brand, size: 16),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  product.name,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (product.description != null && product.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      product.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSizes.sm),
                _RatingChip(product: product),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _PriceBlock(product: product)),
        if (product.flashSale != null)
          SliverToBoxAdapter(child: _FlashBar(sale: product.flashSale!)),
        if (product.offers.isNotEmpty)
          SliverToBoxAdapter(child: _OffersStrip(offers: product.offers)),
        // Real `highlights` field when the merchant filled one in,
        // tag list as a graceful fallback otherwise.
        if (product.highlights.isNotEmpty)
          SliverToBoxAdapter(child: _Highlights(items: product.highlights))
        else if (product.tags.isNotEmpty)
          SliverToBoxAdapter(child: _Highlights(items: product.tags)),
        if (product.description != null && product.description!.length > 80)
          SliverToBoxAdapter(child: _Description(text: product.description!)),
        if (product.specs.isNotEmpty)
          SliverToBoxAdapter(child: _SpecSheet(groups: product.specs)),
        SliverToBoxAdapter(child: _ShopCard(product: product)),
        const SliverToBoxAdapter(child: SizedBox(height: AppSizes.huge)),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.urls,
    required this.controller,
    required this.index,
    required this.onChanged,
  });
  final List<String> urls;
  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        height: 320,
        color: AppColors.heroPanel,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 48, color: AppColors.muted),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: controller,
            itemCount: urls.length,
            onPageChanged: onChanged,
            itemBuilder: (_, i) => Container(
              color: AppColors.heroPanel,
              child: NetworkImageBox(url: resolveImageUrl(urls[i])),
            ),
          ),
        ),
        if (urls.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  Container(
                    width: i == index ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.black : AppColors.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.product});
  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    if (product.ratingAvg == null) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.heroPanel,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text(
              'No reviews yet',
              style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Text(
                product.ratingAvg!.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.star_rounded, color: Colors.white, size: 12),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Text(
          '${product.ratingCount} ratings · ${product.totalSold} sold',
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.product});
  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    final showFlash = product.flashSale != null;
    final price = showFlash ? product.flashSale!.price : product.sellingPrice;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${price.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          if (product.isDiscounted)
            Text(
              '₹${product.mrp.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          const SizedBox(width: AppSizes.sm),
          if (product.isDiscounted)
            Text(
              '${product.discountPct}% off',
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _FlashBar extends StatelessWidget {
  const _FlashBar({required this.sale});
  final ActiveFlashSale sale;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: AppSizes.xs),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: const Color(0xFFFFE3D2),
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFFE05A2A), size: 18),
              const SizedBox(width: 4),
              Text(
                'Flash deal · ${sale.remaining} left',
                style: const TextStyle(
                  color: Color(0xFFE05A2A),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                'Ends ${sale.endAt.hour.toString().padLeft(2, "0")}:${sale.endAt.minute.toString().padLeft(2, "0")}',
                style: const TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: sale.soldPct,
              minHeight: 6,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE05A2A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Highlights',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.black)),
          const SizedBox(height: AppSizes.sm),
          // Bullet list when the merchant filled in real PDP highlights;
          // free-form chips when we're falling back to the tag array
          // (different presentations because the content shapes are
          // different — a tag is a short keyword, a highlight is a
          // descriptive sentence).
          if (items.first.length > 24)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w800)),
                        Expanded(
                          child: Text(
                            t,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: 6,
              children: [
                for (final t in items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.heroPanel,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OffersStrip extends StatelessWidget {
  const _OffersStrip({required this.offers});
  final List<ProductOffer> offers;

  IconData _iconFor(String kind) => switch (kind) {
        'BANK' => Icons.credit_card_rounded,
        'COUPON' => Icons.local_offer_outlined,
        'EMI' => Icons.calendar_month_rounded,
        'EXCHANGE' => Icons.swap_horiz_rounded,
        _ => Icons.percent_rounded,
      };
  Color _tintFor(String kind) => switch (kind) {
        'BANK' => const Color(0xFFE3E8F4),
        'COUPON' => const Color(0xFFFDE2D2),
        'EMI' => const Color(0xFFE6F2EC),
        'EXCHANGE' => const Color(0xFFF9E1EA),
        _ => AppColors.heroPanel,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSizes.sm, 0, AppSizes.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text('Offers',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.black)),
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
              itemBuilder: (_, i) {
                final o = offers[i];
                return Container(
                  width: 240,
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: ShapeDecoration(
                    color: _tintFor(o.kind),
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_iconFor(o.kind), size: 18, color: AppColors.black),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.kind,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              o.headline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            if (o.detail != null)
                              Text(
                                o.detail!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecSheet extends StatelessWidget {
  const _SpecSheet({required this.groups});
  final List<SpecGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Specifications',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.black)),
          const SizedBox(height: AppSizes.sm),
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.sm, bottom: 4),
              child: Text(
                g.title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < g.rows.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md, vertical: AppSizes.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              g.rows[i].label,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              g.rows[i].value,
                              style: const TextStyle(
                                color: AppColors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i != g.rows.length - 1)
                      const Divider(height: 1, color: AppColors.hairline),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About this item',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.black)),
          const SizedBox(height: AppSizes.sm),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.product});
  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    final shop = product.shop;
    if (shop == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ShopProfilePage(slug: shop.slug)),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: ShapeDecoration(
            color: AppColors.white,
            shape: AppShapes.squircle(AppSizes.radiusMd),
            shadows: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  shop.name.isEmpty ? '?' : shop.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sold by ${shop.name}',
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (shop.rating != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${shop.rating!.toStringAsFixed(1)} ★ · ${shop.ratingCount} ratings',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: 'Add to cart',
                onPressed: onAdd,
                icon: Icons.shopping_cart_outlined,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: AppButton.primary(
                label: 'Buy now',
                onPressed: () {
                  onAdd();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CartPage()),
                  );
                },
                icon: Icons.bolt_rounded,
              ),
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.muted),
            const SizedBox(height: AppSizes.md),
            const Text(
              "Couldn't load this product",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: AppSizes.lg),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
