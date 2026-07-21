import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class HomeProductCarousel extends StatelessWidget {
  const HomeProductCarousel({
    super.key,
    required this.title,
    required this.products,
    this.eyebrow,
    this.onSeeAll,
  });

  final String title;
  final String? eyebrow;
  final List<ProductCard> products;

  /// Optional override for the header "see all" target. Defaults to
  /// opening the marketplace search so every section is at least
  /// navigable — sections can pass a specific destination later.
  final VoidCallback? onSeeAll;

  void _handleSeeAll(BuildContext context) {
    if (onSeeAll != null) {
      onSeeAll!();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SearchPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleSeeAll(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            eyebrow!,
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: ShapeDecoration(
                    color: AppColors.black,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: const AppIcon(
                    AppIcons.arrowForwardRounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),
        SizedBox(
          // Tile is (image 158 + name 2-line + price row + a single
          // info line) ≈ 250 at 1.0 text scale, ~290 at 1.3. The few
          // extra px keep us clear of accessibility-scale overflow.
          height: 296,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.md),
            itemBuilder: (context, i) => HomeProductTile(product: products[i]),
          ),
        ),
      ],
    );
  }
}

class HomeProductTile extends StatelessWidget {
  const HomeProductTile({super.key, required this.product, this.width = 158});
  final ProductCard product;

  /// Fixed width when used in a horizontal carousel; pass `null` for
  /// flex sizing inside a grid cell.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPct > 0;
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(productId: product.productId),
          ),
        ),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Image(product: product, hasDiscount: hasDiscount),
              // ClipRect prevents the debug "BOTTOM OVERFLOWED BY N
              // PIXELS" yellow stripe on dense grids whose
              // childAspectRatio doesn't quite match the tile's
              // intrinsic height. The internal column is sized tight
              // (each spacing is the minimum that still reads cleanly)
              // so residual clip is at most 1–2px and never affects
              // the visible content. The trust line is only shown when
              // there's no bank-offer line (discounted products already
              // have a third row from the bank-offer) — keeps the tile
              // height bounded across both states.
              ClipRect(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.sm,
                    AppSizes.sm,
                    AppSizes.sm,
                    AppSizes.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      _PriceRow(product: product, hasDiscount: hasDiscount),
                      if (hasDiscount) ...[
                        const SizedBox(height: AppSizes.xxs),
                        // Same line carries both signals so the tile
                        // keeps a 3-row body regardless of whether the
                        // product is discounted or full-price.
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${product.bankPrice} with Bank',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.info,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (product.freeDelivery) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '·',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Text(
                                'FREE',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  height: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else if (product.freeDelivery || product.isAssured) ...[
                        const SizedBox(height: AppSizes.xxs),
                        Row(
                          children: [
                            if (product.freeDelivery) ...[
                              const AppIcon(
                                AppIcons.localShippingOutlined,
                                size: 10,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'FREE delivery',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  height: 1,
                                ),
                              ),
                            ],
                            if (product.isAssured) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusXs,
                                  ),
                                ),
                                child: const Text(
                                  'ASSURED',
                                  style: TextStyle(
                                    color: AppColors.info,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Image area + every overlay chip. Layered top to bottom:
///   - AD pill (only for sponsored cards) — top-left
///   - Discount % chip — top-left (under AD) — only when `hasDiscount`
///   - Wishlist heart — top-right
///   - Tag pill (e.g. "Limited") — left, just above the rating
///   - Rating pill — bottom-left
class _Image extends StatelessWidget {
  const _Image({required this.product, required this.hasDiscount});
  final ProductCard product;
  final bool hasDiscount;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusMd),
        ),
        child: Container(
          color: product.bgColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: NetworkImageBox(
                  url: resolveImageUrl(product.imageUrl),
                  placeholderColor: product.bgColor,
                ),
              ),
              if (product.isAd)
                const Positioned(top: 6, left: 6, child: _AdChip()),
              if (hasDiscount)
                Positioned(
                  top: product.isAd ? 28 : 6,
                  left: 6,
                  child: _DiscountChip(percent: product.discountPct),
                ),
              const Positioned(top: 6, right: 6, child: _WishHeart()),
              if (product.tag != null)
                Positioned(
                  left: 6,
                  bottom: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                    ),
                    child: Text(
                      product.tag!,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (product.ratingCountRaw > 0)
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: _RatingPill(
                    rating: product.rating,
                    count: product.ratingCount,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountChip extends StatelessWidget {
  const _DiscountChip({required this.percent});
  final int percent;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandStrong],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$percent% OFF',
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AdChip extends StatelessWidget {
  const _AdChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
      child: const Text(
        'AD',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _WishHeart extends StatelessWidget {
  const _WishHeart();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const AppIcon(
        AppIcons.favoriteBorderRounded,
        size: 15,
        color: AppColors.black,
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating, required this.count});
  final double rating;
  final String count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: AppSizes.xxs),
          const AppIcon(
            AppIcons.starRounded,
            color: AppColors.success,
            size: 12,
          ),
          const SizedBox(width: AppSizes.xs),
          Text(
            '($count)',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Price line — bold sale price, struck-through original on its right.
/// When discount > 0 we also add a green "% off" inline so the user
/// reads price + savings without crossing the card.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product, required this.hasDiscount});
  final ProductCard product;
  final bool hasDiscount;

  @override
  Widget build(BuildContext context) {
    // FittedBox scales the whole price line down a hair if the tile's
    // intrinsic width can't host it. Stops the 1-4px horizontal
    // overflow seen in 3-col grids without dropping any signal —
    // tested with ₹64,990 + 28% off on a ~100px tile.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            product.price,
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          if (product.originalPrice.isNotEmpty) ...[
            const SizedBox(width: AppSizes.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                product.originalPrice,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
          // Inline "% off" intentionally dropped — the corner badge on
          // the image already screams the discount, and the duplicate
          // here was the main source of overflow on narrow tiles.
        ],
      ),
    );
  }
}
