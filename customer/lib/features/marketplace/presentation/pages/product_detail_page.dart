import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/cart/presentation/pages/cart_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/home/presentation/services/tracking_service.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/pdp/pdp_content_blocks.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/pdp/pdp_fbt_rail.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/pdp/pdp_gallery.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/pdp/pdp_highlights.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/pdp/pdp_offers_strip.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/pdp/pdp_price_block.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/pdp/pdp_stock_chip.dart';
import 'package:shopxy_customer/features/marketplace/presentation/widgets/pdp/pdp_variant_picker.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/product_reviews_section.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Customer-facing product detail page.
///
/// Single [CustomScrollView] that renders the full page top-to-bottom —
/// gallery, title, variants, price, offers, FBT rail, then the three
/// content sections (Details, Specs, Reviews) stacked vertically with
/// section headers. No horizontal tab swap: everything is reached by
/// scrolling, the same way Amazon's app handles long-form PDPs.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  MarketplaceProduct? _product;
  // Currently-picked variant; drives price/stock display and is sent
  // along with add-to-cart so the cart line can reference it.
  MarketplaceVariant? _selectedVariant;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      context.read<TrackingService>().recordView(widget.productId);
    });
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
      setState(() {
        _product = p;
        _selectedVariant = p.defaultVariant;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  CatalogProduct? _catalogProductForCart() {
    final p = _product;
    if (p == null) return null;
    return CatalogProduct(
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
      shopId: p.shop?.id,
      shopName: p.shop?.name,
      shopSlug: p.shop?.slug,
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
                  selectedVariant: _selectedVariant,
                  onSelectVariant: (v) =>
                      setState(() => _selectedVariant = v),
                ),
      bottomNavigationBar: _product == null
          ? null
          : _ActionBar(catalogProduct: _catalogProductForCart()!, productId: _product!.id),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.product,
    required this.selectedVariant,
    required this.onSelectVariant,
  });
  final MarketplaceProduct product;
  final MarketplaceVariant? selectedVariant;
  final ValueChanged<MarketplaceVariant> onSelectVariant;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.black,
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        SliverToBoxAdapter(
          child: PdpGallery(
            productId: p.id,
            urls: p.images,
            offers: p.offers,
          ),
        ),
        SliverToBoxAdapter(child: _TitleBlock(product: p)),
        SliverToBoxAdapter(
          child: PdpVariantPicker(
            product: p,
            onSelect: onSelectVariant,
          ),
        ),
        SliverToBoxAdapter(
          child: PdpPriceBlock(
            product: p,
            variantOverride: selectedVariant,
          ),
        ),
        SliverToBoxAdapter(
          child: PdpStockChip(
            stockQuantity:
                selectedVariant?.stockQuantity ?? p.stockQuantity,
            lowStockThreshold: 5,
          ),
        ),
        SliverToBoxAdapter(
          child: PdpOffersStrip(offers: p.offers, bankOffers: p.bankOffers),
        ),
        SliverToBoxAdapter(child: PdpFbtRail(productId: p.id)),

        // ── Details section ──────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(child: _SectionHeader(title: 'Details')),
        SliverToBoxAdapter(child: PdpHighlights(items: p.highlights)),
        if (p.contentBlocks.isNotEmpty)
          SliverToBoxAdapter(
            child: PdpContentBlocks(blocks: p.contentBlocks),
          ),
        if (p.description != null && p.description!.length > 80)
          SliverToBoxAdapter(child: _Description(text: p.description!)),
        SliverToBoxAdapter(child: _ShopCard(product: p)),

        // ── Specs section ────────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(child: _SectionHeader(title: 'Specifications')),
        if (p.specs.isEmpty)
          const SliverToBoxAdapter(
            child: _EmptySection(
              icon: Icons.list_alt_outlined,
              title: 'No specifications yet',
              subtitle: "The seller hasn't added a spec sheet for this product.",
            ),
          )
        else
          SliverToBoxAdapter(child: _SpecTabsAndSheet(groups: p.specs)),

        // ── Reviews section ──────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(child: _SectionHeader(title: 'Ratings & reviews')),
        SliverToBoxAdapter(
          child: ProductReviewsSection(
            productId: p.id,
            productName: p.name,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppSizes.huge)),
      ],
    );
  }
}

/// Soft divider between page sections — a hairline above a small
/// breathing space. Keeps section transitions visible without
/// the loudness of a full Divider.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.lg),
      height: AppSizes.sm,
      color: AppColors.heroPanel,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.product});
  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.systemTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SystemTagsRow(tags: product.systemTags),
            ),
          if (product.brand != null) ...[
            Text(
              product.brand!.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            product.name,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          _SoldByChip(product: product),
          if (product.soldLast30d >= 50)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_compact(product.soldLast30d)}+ bought in the past month',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          if (product.description != null && product.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.sm),
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
    );
  }

  /// Coarse rounding to the nearest 50/100/500 — Amazon shows
  /// "200+ bought in past month", not "247 bought". Keeps the line
  /// reading as social proof rather than analytics.
  String _compact(int n) {
    if (n >= 1000) return '${(n ~/ 500) * 500}';
    if (n >= 100) return '${(n ~/ 50) * 50}';
    return '${(n ~/ 10) * 10}';
  }
}

class _SystemTagsRow extends StatelessWidget {
  const _SystemTagsRow({required this.tags});
  final List<String> tags;

  String _label(String tag) => switch (tag) {
        'BESTSELLER' => 'Bestseller',
        'EDITORS_PICK' => "Editor's pick",
        'NEW_ARRIVAL' => 'New arrival',
        'TRENDING' => 'Trending',
        _ => tag,
      };

  // Pull every tag color from the theme so the pills feel like part of
  // the same palette as the rest of the app.
  ({Color bg, Color fg}) _palette(String tag) => switch (tag) {
        'BESTSELLER' =>
          (bg: AppColors.black, fg: AppColors.white),
        'EDITORS_PICK' =>
          (bg: AppColors.info, fg: AppColors.white),
        'NEW_ARRIVAL' =>
          (bg: AppColors.success, fg: AppColors.white),
        'TRENDING' =>
          (bg: AppColors.accentAmber, fg: AppColors.white),
        _ =>
          (bg: AppColors.black, fg: AppColors.white),
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _palette(t).bg,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _label(t),
              style: TextStyle(
                color: _palette(t).fg,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
      ],
    );
  }
}

class _SoldByChip extends StatelessWidget {
  const _SoldByChip({required this.product});
  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    final shop = product.shop;
    if (shop == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShopProfilePage(slug: shop.slug)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sold by ',
            style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          Text(
            shop.name,
            style: const TextStyle(
                color: AppColors.brandStrong,
                fontSize: 12,
                fontWeight: FontWeight.w800),
          ),
          if (shop.isVerified) ...[
            const SizedBox(width: 3),
            const Icon(Icons.verified_rounded,
                color: AppColors.info, size: 13),
          ],
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.brandStrong, size: 14),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.product});
  final MarketplaceProduct product;

  @override
  Widget build(BuildContext context) {
    if (product.ratingAvg == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.heroPanel,
          borderRadius: BorderRadius.circular(2),
        ),
        child: const Text(
          'No reviews yet',
          style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
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
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.star_rounded,
                  color: AppColors.white, size: 12),
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

/// Wraps the spec sheet with an optional Phase D subtab chip row.
/// When any group declares a [SpecGroup.tab], the unique tabs become
/// horizontal pills and the selected one filters the visible groups.
/// When no group declares a tab, falls through to a flat list (the
/// pre-Phase-D behaviour).
class _SpecTabsAndSheet extends StatefulWidget {
  const _SpecTabsAndSheet({required this.groups});
  final List<SpecGroup> groups;

  @override
  State<_SpecTabsAndSheet> createState() => _SpecTabsAndSheetState();
}

class _SpecTabsAndSheetState extends State<_SpecTabsAndSheet> {
  late String? _selectedTab;

  List<String> get _tabs {
    final seen = <String>{};
    final ordered = <String>[];
    for (final g in widget.groups) {
      if (g.tab != null && !seen.contains(g.tab)) {
        seen.add(g.tab!);
        ordered.add(g.tab!);
      }
    }
    return ordered;
  }

  @override
  void initState() {
    super.initState();
    final t = _tabs;
    _selectedTab = t.isEmpty ? null : t.first;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final filtered = _selectedTab == null
        ? widget.groups
        : widget.groups.where((g) => g.tab == _selectedTab).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tabs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSizes.sm),
                itemBuilder: (_, i) {
                  final t = tabs[i];
                  final sel = t == _selectedTab;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.brandSoft : AppColors.white,
                        border: Border.all(
                          color: sel
                              ? AppColors.brand
                              : AppColors.hairline,
                          width: sel ? 1.5 : 1,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          color: sel
                              ? AppColors.brandStrong
                              : AppColors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        _SpecSheet(groups: filtered),
      ],
    );
  }
}

class _SpecSheet extends StatelessWidget {
  const _SpecSheet({required this.groups});
  final List<SpecGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(
                  top: AppSizes.sm, bottom: 4),
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
                          horizontal: AppSizes.md,
                          vertical: AppSizes.sm),
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
                      const Divider(
                          height: 1, color: AppColors.hairline),
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
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.black),
          ),
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
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xxl),
      child: Column(
        children: [
          Icon(icon, color: AppColors.subtle, size: AppSizes.iconXl),
          const SizedBox(height: AppSizes.sm),
          Text(
            title,
            style: const TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
                fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Pinned bottom action bar.
///
/// Three states:
///   • idle          → primary "Add to cart" button (brand color) + secondary
///                     ghost "Buy now" pill that pushes the cart page.
///   • loading       → button shows an inline spinner while the optimistic
///                     write fans out to the server. The user can't double-tap
///                     it.
///   • in-cart       → button collapses into a [- N +] quantity stepper plus a
///                     filled "Go to cart" pill, mirroring the standard
///                     marketplace pattern (Amazon / Flipkart / Myntra).
///
/// The cart provider's [CartProvider.add] / [setQuantity] calls return
/// synchronously after writing the local mirror; the network sync is
/// fire-and-forget. We only show the loading state long enough to
/// debounce double-taps (and as a visual ack that the tap registered).
class _ActionBar extends StatefulWidget {
  const _ActionBar({required this.catalogProduct, required this.productId});
  final CatalogProduct catalogProduct;
  final int productId;

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  bool _busy = false;

  Future<void> _addToCart() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final cart = context.read<CartProvider>();
    final result = cart.add(widget.catalogProduct);
    // Tiny delay so the spinner is perceptible. Cart writes locally
    // first, so without this the state flip is so fast it looks like
    // nothing happened.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() => _busy = false);
    context.read<TrackingService>().recordAddToCart(widget.productId);
    if (result == AddToCartResult.outOfStock) {
      showAppSnackbar(
        context,
        message: 'Out of stock',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    showAppSnackbar(
      context,
      message: result == AddToCartResult.capped
          ? "Reached the maximum we can deliver — added what we can."
          : 'Added to cart',
      tone: AppSnackbarTone.success,
      actionLabel: 'View cart',
      onAction: _openCart,
    );
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CartPage()),
    );
  }

  void _setQuantity(double q) {
    HapticFeedback.selectionClick();
    final cart = context.read<CartProvider>();
    final result = cart.setQuantity(widget.productId, q);
    if (result == AddToCartResult.capped) {
      showAppSnackbar(
        context,
        message: "Reached the maximum we can deliver.",
        tone: AppSnackbarTone.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final line = cart.lineFor(widget.productId);
    final inCart = line != null && line.quantity > 0;
    final outOfStock = !widget.catalogProduct.inStock;

    return Material(
      color: AppColors.white,
      elevation: 8,
      shadowColor: Colors.black12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.sm),
          child: SizedBox(
            height: 52,
            child: outOfStock
                ? const _OutOfStockButton()
                : inCart
                    ? _InCartRow(
                        quantity: line.quantity.toInt(),
                        onIncrement: () =>
                            _setQuantity(line.quantity + 1),
                        onDecrement: () =>
                            _setQuantity(line.quantity - 1),
                        onGoToCart: _openCart,
                      )
                    : _IdleRow(
                        busy: _busy,
                        onAdd: _addToCart,
                        onBuyNow: () async {
                          await _addToCart();
                          if (!mounted) return;
                          _openCart();
                        },
                      ),
          ),
        ),
      ),
    );
  }
}

/// Idle state — "Add to cart" + "Buy now".
class _IdleRow extends StatelessWidget {
  const _IdleRow({
    required this.busy,
    required this.onAdd,
    required this.onBuyNow,
  });
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PrimaryPillButton(
            label: busy ? 'Adding…' : 'Add to cart',
            icon: Icons.shopping_cart_outlined,
            loading: busy,
            // Outline brand button — pairs with the filled "Buy now"
            // on the right so the two CTAs read at the same visual
            // weight without competing.
            kind: _PillKind.outlined,
            onPressed: busy ? null : onAdd,
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _PrimaryPillButton(
            label: 'Buy now',
            icon: Icons.bolt_rounded,
            kind: _PillKind.filled,
            onPressed: busy ? null : onBuyNow,
          ),
        ),
      ],
    );
  }
}

/// In-cart state — stepper + "Go to cart".
class _InCartRow extends StatelessWidget {
  const _InCartRow({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onGoToCart,
  });
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onGoToCart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuantityStepper(
          quantity: quantity,
          onIncrement: onIncrement,
          onDecrement: onDecrement,
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _PrimaryPillButton(
            label: 'Go to cart',
            icon: Icons.arrow_forward_rounded,
            kind: _PillKind.filled,
            onPressed: onGoToCart,
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: ShapeDecoration(
        color: AppColors.brandSoft,
        shape: AppShapes.squircle(
          AppSizes.radiusFull,
          side: const BorderSide(color: AppColors.brand, width: 1.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: quantity <= 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            onPressed: onDecrement,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: AppColors.brandStrong,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 22,
      child: SizedBox(
        width: 44,
        height: 52,
        child: Icon(icon, color: AppColors.brandStrong, size: 20),
      ),
    );
  }
}

class _OutOfStockButton extends StatelessWidget {
  const _OutOfStockButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.disabled,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Out of stock',
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

enum _PillKind { filled, outlined }

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({
    required this.label,
    required this.icon,
    required this.kind,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final IconData icon;
  final _PillKind kind;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final filled = kind == _PillKind.filled;
    final bg = disabled
        ? AppColors.disabled
        : (filled ? AppColors.brand : AppColors.brandSoft);
    final fg = filled
        ? AppColors.white
        : (disabled ? AppColors.muted : AppColors.brandStrong);
    final border = filled
        ? null
        : Border.all(
            color: disabled ? AppColors.hairline : AppColors.brand,
            width: 1.4,
          );

    return Material(
      color: bg,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onPressed,
        child: Container(
          decoration: border == null
              ? null
              : ShapeDecoration(
                  shape: AppShapes.squircle(
                    AppSizes.radiusFull,
                    side: BorderSide(
                      color: disabled ? AppColors.hairline : AppColors.brand,
                      width: 1.4,
                    ),
                  ),
                ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: fg, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
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
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.muted),
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
