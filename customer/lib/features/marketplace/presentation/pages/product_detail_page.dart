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
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/theme/app_shadows.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

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
      setState(() => _error = friendlyError(e));
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
      sellingPrice: p.sellingPrice,
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
          ? const _ProductDetailSkeleton()
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : _Body(
              product: _product!,
              selectedVariant: _selectedVariant,
              onSelectVariant: (v) => setState(() => _selectedVariant = v),
            ),
      bottomNavigationBar: _product == null
          ? null
          : _ActionBar(
              catalogProduct: _catalogProductForCart()!,
              productId: _product!.id,
            ),
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
          child: PdpGallery(productId: p.id, urls: p.images, offers: p.offers),
        ),
        SliverToBoxAdapter(child: _TitleBlock(product: p)),
        SliverToBoxAdapter(
          child: PdpVariantPicker(product: p, onSelect: onSelectVariant),
        ),
        SliverToBoxAdapter(
          child: PdpPriceBlock(product: p, variantOverride: selectedVariant),
        ),
        SliverToBoxAdapter(
          child: PdpStockChip(
            stockQuantity: selectedVariant?.stockQuantity ?? p.stockQuantity,
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
          SliverToBoxAdapter(child: PdpContentBlocks(blocks: p.contentBlocks)),
        if (p.description != null && p.description!.length > 80)
          SliverToBoxAdapter(child: _Description(text: p.description!)),
        SliverToBoxAdapter(child: _ShopCard(product: p)),

        // ── Specs section ────────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(
          child: _SectionHeader(title: 'Specifications'),
        ),
        if (p.specs.isEmpty)
          const SliverToBoxAdapter(
            child: _EmptySection(
              icon: AppIcons.listAltOutlined,
              title: 'No specifications yet',
              subtitle:
                  "The seller hasn't added a spec sheet for this product.",
            ),
          )
        else
          SliverToBoxAdapter(child: _SpecTabsAndSheet(groups: p.specs)),

        // ── Reviews section ──────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(
          child: _SectionHeader(title: 'Ratings & reviews'),
        ),
        SliverToBoxAdapter(
          child: ProductReviewsSection(productId: p.id, productName: p.name),
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
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.black,
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
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.systemTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: _SystemTagsRow(tags: product.systemTags),
            ),
          if (product.brand != null) ...[
            Text(
              product.brand!.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
          ],
          Text(
            product.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.black,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          _SoldByChip(product: product),
          if (product.soldLast30d >= 50)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xs),
              child: Text(
                '${_compact(product.soldLast30d)}+ bought in the past month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
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
    'BESTSELLER' => (bg: AppColors.black, fg: AppColors.white),
    'EDITORS_PICK' => (bg: AppColors.info, fg: AppColors.white),
    'NEW_ARRIVAL' => (bg: AppColors.success, fg: AppColors.white),
    'TRENDING' => (bg: AppColors.accentAmber, fg: AppColors.white),
    _ => (bg: AppColors.black, fg: AppColors.white),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.xs,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sm,
              vertical: AppSizes.xs,
            ),
            decoration: BoxDecoration(
              color: _palette(t).bg,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _label(t),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
          Text(
            'Sold by ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            shop.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.brandStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (shop.isVerified) ...[
            const SizedBox(width: AppSizes.xs),
            const AppIcon(
              AppIcons.verifiedRounded,
              color: AppColors.info,
              size: AppSizes.iconSm,
            ),
          ],
          const SizedBox(width: AppSizes.xs),
          const AppIcon(
            AppIcons.chevronRightRounded,
            color: AppColors.brandStrong,
            size: AppSizes.iconSm,
          ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.heroPanel,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          'No reviews yet',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: AppSizes.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Text(
                product.ratingAvg!.toStringAsFixed(1),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              const AppIcon(
                AppIcons.starRounded,
                color: AppColors.white,
                size: 12,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Text(
          '${product.ratingCount} ratings · ${product.totalSold} sold',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
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
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: SizedBox(
              height: AppSizes.xxxl,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
                itemBuilder: (_, i) {
                  final t = tabs[i];
                  final sel = t == _selectedTab;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.brandSoft : AppColors.white,
                        border: Border.all(
                          color: sel ? AppColors.brand : AppColors.hairline,
                          width: sel ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                      ),
                      child: Text(
                        t,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: sel ? AppColors.brandStrong : AppColors.black,
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
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSizes.sm,
                bottom: AppSizes.xs,
              ),
              child: Text(
                g.title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
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
                        vertical: AppSizes.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              g.rows[i].label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              g.rows[i].value,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.black,
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
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.black,
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
            shadows: AppShadows.floating,
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (shop.rating != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSizes.xs),
                        child: Text(
                          '${shop.rating!.toStringAsFixed(1)} ★ · ${shop.ratingCount} ratings',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const AppIcon(
                AppIcons.chevronRightRounded,
                color: AppColors.muted,
              ),
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
  final AppIconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xxl),
      child: Column(
        children: [
          AppIcon(icon, color: AppColors.subtle, size: AppSizes.iconXl),
          const SizedBox(height: AppSizes.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              height: 1.35,
            ),
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
    await Future<void>.delayed(AppDurations.searchDebounce);
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CartPage()));
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: AppShadows.floating,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.md,
            AppSizes.sm,
            AppSizes.md,
            AppSizes.sm,
          ),
          child: SizedBox(
            height: 52,
            child: outOfStock
                ? const _OutOfStockButton()
                : inCart
                ? _InCartRow(
                    quantity: line.quantity.toInt(),
                    onIncrement: () => _setQuantity(line.quantity + 1),
                    onDecrement: () => _setQuantity(line.quantity - 1),
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
            icon: AppIcons.shoppingCartOutlined,
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
            icon: AppIcons.boltRounded,
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
            icon: AppIcons.arrowForwardRounded,
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
                ? AppIcons.deleteOutlineRounded
                : AppIcons.removeRounded,
            onPressed: onDecrement,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: AppSizes.xxxl),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.brandStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepperButton(icon: AppIcons.addRounded, onPressed: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});
  final AppIconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 22,
      child: SizedBox(
        width: 44,
        height: 52,
        child: AppIcon(
          icon,
          color: AppColors.brandStrong,
          size: AppSizes.iconMd,
        ),
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
      child: Text(
        'Out of stock',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
  final AppIconData icon;
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
                  width: AppSizes.iconMd,
                  height: AppSizes.iconMd,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(icon, color: fg, size: AppSizes.iconMd),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
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

// ── Skeleton / shimmer loading state ────────────────────────────────────────

/// Full-page skeleton that mirrors the real [_Body] layout so the user
/// sees the structural chrome immediately while the product data fetches.
/// Uses [CustomScrollView] + slivers so scroll physics match the real page.
class _ProductDetailSkeleton extends StatelessWidget {
  const _ProductDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // ── App bar placeholder ──────────────────────────────────
        SliverAppBar(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.black,
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        // ── Gallery placeholder ──────────────────────────────────
        const SliverToBoxAdapter(child: _GallerySkeleton()),

        // ── Title block placeholder ──────────────────────────────
        const SliverToBoxAdapter(child: _TitleSkeleton()),

        // ── Variant picker placeholder ───────────────────────────
        const SliverToBoxAdapter(child: _VariantPickerSkeleton()),

        // ── Price block placeholder ──────────────────────────────
        const SliverToBoxAdapter(child: _PriceBlockSkeleton()),

        // ── Stock chip placeholder ───────────────────────────────
        const SliverToBoxAdapter(child: _StockChipSkeleton()),

        // ── Offers strip placeholder ─────────────────────────────
        const SliverToBoxAdapter(child: _OffersStripSkeleton()),

        // ── FBT rail placeholder ─────────────────────────────────
        const SliverToBoxAdapter(child: _FbtRailSkeleton()),

        // ── Details section ──────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(child: _SkeletonSectionHeader()),
        const SliverToBoxAdapter(child: _DetailsSkeleton()),

        // ── Specs section ────────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(child: _SkeletonSectionHeader()),
        const SliverToBoxAdapter(child: _SpecsSkeleton()),

        // ── Reviews section ──────────────────────────────────────
        const SliverToBoxAdapter(child: _SectionDivider()),
        const SliverToBoxAdapter(child: _SkeletonSectionHeader()),
        const SliverToBoxAdapter(child: _ReviewsSkeleton()),

        const SliverToBoxAdapter(child: SizedBox(height: AppSizes.huge)),
      ],
    );
  }
}

/// Tall image gallery rectangle.
class _GallerySkeleton extends StatelessWidget {
  const _GallerySkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmerBox(width: double.infinity, height: 320, radius: 0);
  }
}

/// Brand label + two-line product name + short description lines.
class _TitleSkeleton extends StatelessWidget {
  const _TitleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand label
          AppShimmerLine(widthFactor: 0.25, height: 10),
          const SizedBox(height: AppSizes.sm),
          // Product name line 1
          AppShimmerLine(widthFactor: 0.85, height: 18),
          const SizedBox(height: AppSizes.xs),
          // Product name line 2
          AppShimmerLine(widthFactor: 0.65, height: 18),
          const SizedBox(height: AppSizes.sm),
          // Sold-by chip
          AppShimmerBox(width: 140, height: 14, radius: AppSizes.radiusSm),
          const SizedBox(height: AppSizes.sm),
          // Description line 1
          AppShimmerLine(widthFactor: 1.0, height: 12),
          const SizedBox(height: AppSizes.xs),
          // Description line 2
          AppShimmerLine(widthFactor: 0.75, height: 12),
          const SizedBox(height: AppSizes.sm),
          // Rating chip
          AppShimmerBox(width: 90, height: 22, radius: AppSizes.radiusSm),
        ],
      ),
    );
  }
}

/// Row of variant chips.
class _VariantPickerSkeleton extends StatelessWidget {
  const _VariantPickerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            AppShimmerBox(width: 56, height: 32, radius: AppSizes.radiusFull),
            if (i < 3) const SizedBox(width: AppSizes.sm),
          ],
        ],
      ),
    );
  }
}

/// Price + MRP + discount badge block.
class _PriceBlockSkeleton extends StatelessWidget {
  const _PriceBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppShimmerBox(width: 100, height: 28, radius: AppSizes.radiusSm),
          const SizedBox(width: AppSizes.sm),
          AppShimmerBox(width: 60, height: 16, radius: AppSizes.radiusSm),
          const SizedBox(width: AppSizes.sm),
          AppShimmerBox(width: 48, height: 20, radius: AppSizes.radiusSm),
        ],
      ),
    );
  }
}

/// Small stock-availability chip.
class _StockChipSkeleton extends StatelessWidget {
  const _StockChipSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: AppShimmerBox(width: 80, height: 22, radius: AppSizes.radiusFull),
    );
  }
}

/// Horizontal offers strip (one wide rectangle).
class _OffersStripSkeleton extends StatelessWidget {
  const _OffersStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: AppShimmerBox(
        width: double.infinity,
        height: 44,
        radius: AppSizes.radiusSm,
      ),
    );
  }
}

/// Frequently-bought-together horizontal rail — 4 thumbnail cards.
class _FbtRailSkeleton extends StatelessWidget {
  const _FbtRailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        0,
        AppSizes.sm,
      ),
      child: SizedBox(
        height: 120,
        child: Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerBox(
                    width: 80,
                    height: 80,
                    radius: AppSizes.radiusSm,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  AppShimmerLine(widthFactor: 0.6, height: 10),
                ],
              ),
              const SizedBox(width: AppSizes.md),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header line — mirrors [_SectionHeader] width.
class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: AppShimmerBox(width: 120, height: 16, radius: AppSizes.radiusSm),
    );
  }
}

/// Details section — highlight rows + description lines.
class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 4; i++) ...[
            Row(
              children: [
                AppShimmerBox(width: 16, height: 16, radius: AppSizes.radiusSm),
                const SizedBox(width: AppSizes.sm),
                AppShimmerLine(widthFactor: 0.7, height: 12),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
          ],
          const SizedBox(height: AppSizes.sm),
          AppShimmerLine(widthFactor: 1.0, height: 12),
          const SizedBox(height: AppSizes.xs),
          AppShimmerLine(widthFactor: 0.9, height: 12),
          const SizedBox(height: AppSizes.xs),
          AppShimmerLine(widthFactor: 0.8, height: 12),
        ],
      ),
    );
  }
}

/// Specs section — two-column key/value rows inside a rounded card.
class _SpecsSkeleton extends StatelessWidget {
  const _SpecsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: AppColors.hairline),
        ),
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          children: [
            for (var i = 0; i < 5; i++) ...[
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: AppShimmerLine(widthFactor: 0.75, height: 11),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: AppShimmerLine(widthFactor: 0.55, height: 11),
                  ),
                ],
              ),
              if (i < 4) ...[
                const SizedBox(height: AppSizes.sm),
                const Divider(height: 1, color: AppColors.hairline),
                const SizedBox(height: AppSizes.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Reviews section — rating summary bar + 2 review card placeholders.
class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating summary row
          Row(
            children: [
              AppShimmerBox(width: 56, height: 56, radius: AppSizes.radiusSm),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      AppShimmerLine(widthFactor: 0.9 - i * 0.2, height: 8),
                      if (i < 2) const SizedBox(height: AppSizes.xs),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          // 2 review card placeholders
          for (var i = 0; i < 2; i++) ...[
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              margin: const EdgeInsets.only(bottom: AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppShimmerBox(
                        width: 32,
                        height: 32,
                        radius: AppSizes.radiusFull,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppShimmerLine(widthFactor: 0.4, height: 11),
                          const SizedBox(height: AppSizes.xs),
                          AppShimmerLine(widthFactor: 0.25, height: 9),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  AppShimmerLine(widthFactor: 1.0, height: 11),
                  const SizedBox(height: AppSizes.xs),
                  AppShimmerLine(widthFactor: 0.8, height: 11),
                  const SizedBox(height: AppSizes.xs),
                  AppShimmerLine(widthFactor: 0.6, height: 11),
                ],
              ),
            ),
          ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              AppIcons.cloudOffRounded,
              size: AppSizes.iconHuge,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              "Couldn't load this product",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.lg),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
