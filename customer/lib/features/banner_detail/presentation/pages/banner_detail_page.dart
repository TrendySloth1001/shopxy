import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/banner_detail/data/datasources/banner_detail_remote_data_source.dart';
import 'package:shopxy_customer/features/banner_detail/domain/entities/banner_detail.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Banner-detail page: the banner image at the top, followed by a
/// responsive grid of the products pinned to it (with banner-discounted
/// prices). Reached by tapping a home banner that has `productCount > 0`.
class BannerDetailPage extends StatefulWidget {
  const BannerDetailPage({super.key, required this.bannerId});
  final int bannerId;

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage> {
  BannerDetail? _detail;
  bool _loading = true;
  String? _error;

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
      final ds = context.read<BannerDetailRemoteDataSource>();
      final detail = await ds.fetchBannerDetail(widget.bannerId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Featured'),
      ),
      body: _loading && _detail == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _Body(detail: _detail!),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});
  final BannerDetail detail;

  @override
  Widget build(BuildContext context) {
    final products = detail.products;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _BannerHeaderImage(banner: detail.banner)),
        if (products.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.lg),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                // Responsive column count: target ~180px tiles, clamp
                // to 2–4 columns so the grid reads well on phones and
                // wide tablets alike.
                final width = constraints.crossAxisExtent;
                final columns = (width / 180).floor().clamp(2, 4);
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSizes.md,
                    mainAxisSpacing: AppSizes.md,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _BannerProductTile(product: products[i]),
                    childCount: products.length,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _BannerHeaderImage extends StatelessWidget {
  const _BannerHeaderImage({required this.banner});
  final BannerHeader banner;

  // Wide marketing strip — matches the home hero aspect ratio.
  static const double _aspectRatio = 16 / 7;

  @override
  Widget build(BuildContext context) {
    final url = resolveImageUrl(banner.imageUrl);
    if (url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.xs,
      ),
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: NetworkImageBox(
          url: url,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }
}

class _BannerProductTile extends StatelessWidget {
  const _BannerProductTile({required this.product});
  final BannerProduct product;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.hasDiscount;
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
            builder: (_) => ProductDetailPage(productId: product.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TileImage(product: product),
            ClipRect(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.sm),
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
                    const SizedBox(height: 4),
                    _PriceRow(product: product, hasDiscount: hasDiscount),
                    if (product.ratingCount > 0) ...[
                      const SizedBox(height: 4),
                      _RatingChip(product: product),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileImage extends StatelessWidget {
  const _TileImage({required this.product});
  final BannerProduct product;

  @override
  Widget build(BuildContext context) {
    final url = resolveImageUrl(product.imageUrl);
    final radius = BorderRadius.vertical(
      top: Radius.circular(AppSizes.radiusMd),
    );
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: NetworkImageBox(
            url: url,
            fit: BoxFit.cover,
            borderRadius: radius,
          ),
        ),
        if (product.discountPct > 0)
          Positioned(
            top: AppSizes.sm,
            left: AppSizes.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                '${product.discountPct}% OFF',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product, required this.hasDiscount});
  final BannerProduct product;
  final bool hasDiscount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            AppFormat.rupees(product.salePrice),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: AppSizes.xs),
          Flexible(
            child: Text(
              AppFormat.rupees(product.sellingPrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.1,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.product});
  final BannerProduct product;

  @override
  Widget build(BuildContext context) {
    final count = product.ratingCount;
    final prettyCount =
        count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.star, color: AppColors.white, size: 10),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.xs),
        Text(
          '($prettyCount)',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSizes.xxl),
        child: Text(
          'No products in this collection yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 14),
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
        padding: const EdgeInsets.all(AppSizes.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.muted, size: AppSizes.iconXl),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: AppSizes.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
