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

  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount = product.discountPct > 0;
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    _PriceRow(product: product, hasDiscount: hasDiscount),
                    if (product.freeDelivery || product.isAssured) ...[
                      const SizedBox(height: AppSizes.xs),
                      Wrap(
                        spacing: AppSizes.xs,
                        runSpacing: AppSizes.xxs,
                        children: [
                          if (product.freeDelivery)
                            const TilePill(
                              icon: AppIcons.localShippingOutlined,
                              label: 'FREE delivery',
                              fg: AppColors.success,
                              bg: AppColors.successSoft,
                            ),
                          if (product.isAssured)
                            const TilePill(
                              label: 'ASSURED',
                              fg: AppColors.info,
                              bg: AppColors.infoSoft,
                            ),
                        ],
                      ),
                    ],
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

class TilePill extends StatelessWidget {
  const TilePill({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
  });
  final String label;
  final Color fg;
  final Color bg;
  final AppIconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs, vertical: 2),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.product, required this.hasDiscount});
  final ProductCard product;
  final bool hasDiscount;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
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
            if (hasDiscount)
              Positioned(
                top: 6,
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
                bottom: AppSizes.sm,
                left: AppSizes.sm,
                child: _RatingPill(
                  rating: product.rating,
                  count: product.ratingCount,
                ),
              ),
          ],
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

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product, required this.hasDiscount});
  final ProductCard product;
  final bool hasDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (product.originalPrice.isNotEmpty) ...[
            const SizedBox(width: AppSizes.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                product.originalPrice,
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  decoration: TextDecoration.lineThrough,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
