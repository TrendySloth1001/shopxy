import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_blocks.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/pages/section_products_page.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_ad_strip.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_brand_spotlight.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_collection_banner.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_curated_rail.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_flash_deals.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_product_carousel.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_recently_viewed.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Renders any `HomeBlock` to a widget. Lives next to the block model
/// so adding a new layout means: add a class to `home_blocks.dart`,
/// add a `case` here, write the widget below.
class HomeFeedBlock extends StatelessWidget {
  const HomeFeedBlock({super.key, required this.block});
  final HomeBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      MosaicBlock b => _MosaicBlock(block: b),
      Grid2ColBlock b => _GridBlock(
          eyebrow: b.eyebrow,
          title: b.title,
          products: b.products,
          columns: 2,
        ),
      Grid3CompactBlock b => _GridBlock(
          eyebrow: b.eyebrow,
          title: b.title,
          products: b.products,
          columns: 3,
        ),
      VerticalCardsBlock b => _VerticalCardsBlock(block: b),
      ReelsTallBlock b => _ReelsBlock(block: b),
      CategoryCapsuleBlock b => _CategoryCapsuleBlock(block: b),
      QuickAddChipsBlock b => _QuickAddChipsBlock(block: b),
      ComparisonBlock b => _ComparisonBlock(block: b),
      CarouselBlock b => HomeProductCarousel(
          eyebrow: b.eyebrow,
          title: b.title,
          products: b.products,
          onSeeAll: () => _openSection(
            context,
            eyebrow: b.eyebrow,
            title: b.title,
            products: b.products,
          ),
        ),
      CuratedRailBlock b => HomeCuratedRail(slide: b.slide),
      CollectionBannerBlock b =>
        HomeCollectionBanner(tiles: b.tiles, title: b.title),
      SponsoredCarouselBlock b => HomeProductCarousel(
          eyebrow: 'SPONSORED',
          title: 'Promoted by merchants',
          products: b.products,
          onSeeAll: () => _openSection(
            context,
            eyebrow: 'SPONSORED',
            title: 'Promoted by merchants',
            products: b.products,
          ),
        ),
      RecentlyViewedBlock b => HomeRecentlyViewed(items: b.products),
      HeroSingleBlock b => HomeHeroCarousel(slides: [b.slide]),
      AdSingleBlock b => HomeAdStrip(slides: [b.slide]),
      PromoSingleBlock b => HomeAdStrip(slides: [b.slide]),
      FlashSingleBlock b => HomeFlashDeals(deals: [b.deal]),
      SpotlightSingleBlock b => HomeBrandSpotlight(brands: [b.spotlight]),
      PosterProductBlock b => _PosterProductBlock(block: b),
      LeaderboardBlock b => _LeaderboardBlock(block: b),
      BrandFocusBlock b => _BrandFocusBlock(block: b),
      PriceBandBlock b => _PriceBandBlock(block: b),
      ZigZagDuoBlock b => _ZigZagDuoBlock(block: b),
      ShopShowcaseBlock b => _ShopShowcaseBlock(block: b),
    };
  }
}

void _openSection(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required List<ProductCard> products,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SectionProductsPage(
        eyebrow: eyebrow,
        title: title,
        products: products,
      ),
    ),
  );
}

void _openProduct(BuildContext context, ProductCard p) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductDetailPage(productId: p.productId),
    ),
  );
}

/// Eyebrow + title pair used by every block. Compact, brand-coloured
/// eyebrow on top of a heavier title. No tap action — the section can
/// be navigated via the "See all" affordance on relevant blocks; this
/// header just labels the content.
class _BlockHeader extends StatelessWidget {
  const _BlockHeader({
    required this.eyebrow,
    required this.title,
    this.onSeeAll,
  });
  final String eyebrow;
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        0,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.surfaceTint,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: AppColors.black),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Mosaic 1+2 ─────────────────────────────────────────
/// One big square hero on the left, two stacked smaller cards on the
/// right. Breaks the rhythm of horizontal scrolling by offering a
/// "pick one" first impression.
class _MosaicBlock extends StatelessWidget {
  const _MosaicBlock({required this.block});
  final MosaicBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BlockHeader(eyebrow: block.eyebrow, title: block.title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: SizedBox(
            height: 280,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: _MosaicCard(product: block.hero, isHero: true),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Expanded(child: _MosaicCard(product: block.topRight)),
                      const SizedBox(height: AppSizes.md),
                      Expanded(child: _MosaicCard(product: block.bottomRight)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MosaicCard extends StatelessWidget {
  const _MosaicCard({required this.product, this.isHero = false});
  final ProductCard product;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProduct(context, product),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          decoration: ShapeDecoration(
            color: product.bgColor,
            shape: AppShapes.squircle(AppSizes.radiusLg),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetworkImageBox(
                url: resolveImageUrl(product.imageUrl),
                placeholderColor: product.bgColor,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      product.name,
                      maxLines: isHero ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: isHero ? 15 : 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.price,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: isHero ? 17 : 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grid (2-col / 3-col compact) ───────────────────────
/// Shared grid renderer used by both the 2-column and the 3-column
/// compact variants. The only thing that changes between them is the
/// column count + a slightly tighter aspect ratio at 3-col.
class _GridBlock extends StatelessWidget {
  const _GridBlock({
    required this.eyebrow,
    required this.title,
    required this.products,
    required this.columns,
  });
  final String eyebrow;
  final String title;
  final List<ProductCard> products;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BlockHeader(
          eyebrow: eyebrow,
          title: title,
          onSeeAll: () => _openSection(
            context,
            eyebrow: eyebrow,
            title: title,
            products: products,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSizes.md,
              crossAxisSpacing: AppSizes.md,
              // Lower ratio → taller tile. Image is square (1:1), and the
              // body (name 2 lines + price row + delivery/bank line + 16px
              // padding) needs ~88px of vertical space. At 3-col tile
              // widths the math runs ~101 wide, so 101/0.55 ≈ 184 → 83px
              // body. At 2-col ~158 wide, 158/0.62 ≈ 255 → 97px body.
              childAspectRatio: columns == 3 ? 0.55 : 0.62,
            ),
            itemBuilder: (_, i) => HomeProductTile(
              product: products[i],
              width: null,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Vertical full-bleed ────────────────────────────────
/// Big-image, premium feel cards stacked vertically. Three by default —
/// any more starts to feel padded.
class _VerticalCardsBlock extends StatelessWidget {
  const _VerticalCardsBlock({required this.block});
  final VerticalCardsBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BlockHeader(eyebrow: block.eyebrow, title: block.title),
        ...block.products.map((p) => Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                0,
                AppSizes.lg,
                AppSizes.md,
              ),
              child: _VerticalCard(product: p),
            )),
      ],
    );
  }
}

class _VerticalCard extends StatelessWidget {
  const _VerticalCard({required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProduct(context, product),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          decoration: ShapeDecoration(
            color: AppColors.white,
            shape: AppShapes.squircle(AppSizes.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Container(
                  color: product.bgColor,
                  child: NetworkImageBox(
                    url: resolveImageUrl(product.imageUrl),
                    placeholderColor: product.bgColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          product.price,
                          style: const TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          product.originalPrice,
                          style: const TextStyle(
                            color: AppColors.muted,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: ShapeDecoration(
                            color: AppColors.successSoft,
                            shape: AppShapes.squircle(AppSizes.radiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${product.rating.toStringAsFixed(1)} (${product.ratingCount})',
                                style: const TextStyle(
                                  color: AppColors.success,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reels-style tall ───────────────────────────────────
/// Vertical 9:16 cards in a horizontal scroller. The image dominates;
/// price + title sit on a translucent gradient at the foot of the card
/// to keep the visual energy on the photo.
class _ReelsBlock extends StatelessWidget {
  const _ReelsBlock({required this.block});
  final ReelsTallBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BlockHeader(eyebrow: block.eyebrow, title: block.title),
        SizedBox(
          height: 320,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            itemCount: block.products.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.md),
            itemBuilder: (_, i) => _ReelCard(product: block.products[i]),
          ),
        ),
      ],
    );
  }
}

class _ReelCard extends StatelessWidget {
  const _ReelCard({required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProduct(context, product),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: Container(
            decoration: ShapeDecoration(
              color: product.bgColor,
              shape: AppShapes.squircle(AppSizes.radiusLg),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkImageBox(
                  url: resolveImageUrl(product.imageUrl),
                  placeholderColor: product.bgColor,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category capsule ───────────────────────────────────
/// Mini "In `<Category>`" section with a 4-product grid. Visually anchored
/// to the canvas with a coloured chip header so the eye registers it as
/// a category capsule, not just another carousel.
class _CategoryCapsuleBlock extends StatelessWidget {
  const _CategoryCapsuleBlock({required this.block});
  final CategoryCapsuleBlock block;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.brandSoft,
          shape: AppShapes.squircle(AppSizes.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.brand,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Text(
                    block.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openSection(
                    context,
                    eyebrow: 'CATEGORY',
                    title: block.category,
                    products: block.products,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppColors.brandStrong,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: block.products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppSizes.sm,
                crossAxisSpacing: AppSizes.sm,
                // Square image (1:1) + 2-line body (name + price) needs
                // ~55% headroom under the image at 4-col tile widths.
                childAspectRatio: 0.55,
              ),
              itemBuilder: (_, i) => _CapsuleTile(product: block.products[i]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapsuleTile extends StatelessWidget {
  const _CapsuleTile({required this.product});
  final ProductCard product;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProduct(context, product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Container(
                color: product.bgColor,
                child: NetworkImageBox(
                  url: resolveImageUrl(product.imageUrl),
                  placeholderColor: product.bgColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            product.price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick-add chips ────────────────────────────────────
/// Compact horizontally-scrolling chip cards. Tapping the body opens
/// the PDP; the trailing + button is wired to the same destination for
/// now (a true server-side quick-add would need the catalog product).
class _QuickAddChipsBlock extends StatelessWidget {
  const _QuickAddChipsBlock({required this.block});
  final QuickAddChipsBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            0,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 6),
              Text(
                block.title,
                style: const TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            itemCount: block.products.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
            itemBuilder: (_, i) => _QuickAddChip(product: block.products[i]),
          ),
        ),
      ],
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  const _QuickAddChip({required this.product});
  final ProductCard product;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProduct(context, product),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusFull,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: product.bgColor,
                shape: BoxShape.circle,
              ),
              child: NetworkImageBox(
                url: resolveImageUrl(product.imageUrl),
                placeholderColor: product.bgColor,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    product.price,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comparison 2-up ────────────────────────────────────
/// Two products side-by-side with a "vs" splitter. Implicit prompt to
/// shop by feature/price comparison rather than browsing.
class _ComparisonBlock extends StatelessWidget {
  const _ComparisonBlock({required this.block});
  final ComparisonBlock block;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            0,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: Text(
            block.title,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _CompareCard(product: block.left)),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'vs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(child: _CompareCard(product: block.right)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.product});
  final ProductCard product;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openProduct(context, product),
      child: Container(
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: product.bgColor,
                child: NetworkImageBox(
                  url: resolveImageUrl(product.imageUrl),
                  placeholderColor: product.bgColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.price,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.success,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${product.rating.toStringAsFixed(1)} · ${product.ratingCount}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

// ── Round-8 layout designs ─────────────────────────────────────

/// Editorial single-product poster. Full-bleed image, eyebrow + name
/// overlay, price chip and "Shop now" CTA. Designed to break up a
/// scroll of grid/carousel patterns.
class _PosterProductBlock extends StatelessWidget {
  const _PosterProductBlock({required this.block});
  final PosterProductBlock block;
  @override
  Widget build(BuildContext context) {
    final p = block.product;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openProduct(context, p),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: AspectRatio(
            aspectRatio: 16 / 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkImageBox(
                  url: resolveImageUrl(p.imageUrl),
                  placeholderColor: p.bgColor,
                ),
                // Gradient scrim so the overlay text stays legible
                // regardless of the underlying photo.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSizes.lg,
                  right: AppSizes.lg,
                  bottom: AppSizes.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        block.eyebrow,
                        style: const TextStyle(
                          color: Colors.white,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              p.price,
                              style: const TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Shop now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
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
      ),
    );
  }
}

/// Numbered top-N ranking. Rank chip on the left, product card body
/// on the right. The rank chip is what makes this read as "top picks"
/// instead of "another carousel".
class _LeaderboardBlock extends StatelessWidget {
  const _LeaderboardBlock({required this.block});
  final LeaderboardBlock block;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Text(
            block.title,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          itemCount: block.products.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
          itemBuilder: (_, i) => _LeaderboardRow(
            rank: i + 1,
            product: block.products[i],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.product});
  final int rank;
  final ProductCard product;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        onTap: () => _openProduct(context, product),
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? AppColors.warning
                      : (rank <= 3 ? AppColors.brand : AppColors.heroPanel),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rank <= 3 ? Colors.white : AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: NetworkImageBox(
                    url: resolveImageUrl(product.imageUrl),
                    placeholderColor: product.bgColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          product.price,
                          style: const TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (product.originalPrice.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            product.originalPrice,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Spotlight: <brand>" — brand label + grid of products from that
/// brand. Helps customers shop by manufacturer rather than category.
class _BrandFocusBlock extends StatelessWidget {
  const _BrandFocusBlock({required this.block});
  final BrandFocusBlock block;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.heroPanel,
          shape: AppShapes.squircle(AppSizes.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.black,
                    shape: AppShapes.squircle(99),
                  ),
                  child: const Text(
                    'BRAND SPOTLIGHT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.brand,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: block.products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSizes.md,
                crossAxisSpacing: AppSizes.md,
                childAspectRatio: 0.55,
              ),
              itemBuilder: (_, i) => HomeProductTile(
                product: block.products[i],
                width: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Under ₹999" themed strip — chunky price callout on the left,
/// horizontal product carousel on the right. The price label is the
/// hero so the rail reads as a deal hunt, not just another carousel.
class _PriceBandBlock extends StatelessWidget {
  const _PriceBandBlock({required this.block});
  final PriceBandBlock block;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.success,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: Text(
                  block.ceilingLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              const Expanded(
                child: Text(
                  'Easy on the wallet',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        SizedBox(
          height: 296,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            itemCount: block.products.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.md),
            itemBuilder: (_, i) => HomeProductTile(product: block.products[i]),
          ),
        ),
      ],
    );
  }
}

/// Editorial L-shaped duo — one tall hero card on the left, a square
/// pair card on the right. Reads as a "set" / styled outfit moment.
class _ZigZagDuoBlock extends StatelessWidget {
  const _ZigZagDuoBlock({required this.block});
  final ZigZagDuoBlock block;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.title,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            height: 320,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _DuoCard(product: block.hero, tall: true),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: _DuoCard(product: block.pair, tall: false),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.brand,
                          shape: AppShapes.squircle(99),
                        ),
                        child: const Text(
                          'BEST PAIR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
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

class _DuoCard extends StatelessWidget {
  const _DuoCard({required this.product, required this.tall});
  final ProductCard product;
  final bool tall;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        onTap: () => _openProduct(context, product),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: NetworkImageBox(
                  url: resolveImageUrl(product.imageUrl),
                  placeholderColor: product.bgColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: tall ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.price,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Visit <shop>" — small-merchant spotlight. Shop name + tagline +
/// 4-tile product grid. Drives discovery of individual shops rather
/// than just categories.
class _ShopShowcaseBlock extends StatelessWidget {
  const _ShopShowcaseBlock({required this.block});
  final ShopShowcaseBlock block;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.heroPanel,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.black,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'VISIT SHOP',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        block.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.black,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: block.products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppSizes.sm,
                crossAxisSpacing: AppSizes.sm,
                childAspectRatio: 0.55,
              ),
              itemBuilder: (_, i) => _CapsuleTile(product: block.products[i]),
            ),
          ],
        ),
      ),
    );
  }
}
