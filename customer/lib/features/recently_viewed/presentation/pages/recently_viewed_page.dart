import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/recently_viewed/data/datasources/recently_viewed_remote_data_source.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart' show AppShimmerLine;
import 'package:shopxy_customer/shared/format/friendly_error.dart';

/// Per-user "recently viewed" page. Pulls the capped (≤20) list from
/// `GET /me/recently-viewed` and renders it as a 2-col grid so the
/// user can re-open something they were just looking at without
/// digging through search or categories.
class RecentlyViewedPage extends StatefulWidget {
  const RecentlyViewedPage({super.key});

  @override
  State<RecentlyViewedPage> createState() => _RecentlyViewedPageState();
}

class _RecentlyViewedPageState extends State<RecentlyViewedPage> {
  late Future<List<ProductCard>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProductCard>> _load() {
    return context.read<RecentlyViewedRemoteDataSource>().list();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'Recently viewed'),
      body: FutureBuilder<List<ProductCard>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _LoadingGrid();
          }
          if (snap.hasError) {
            return _ErrorBlock(
              message: friendlyError(snap.error ?? ''),
              onRetry: _refresh,
            );
          }
          final items = snap.data ?? const <ProductCard>[];
          if (items.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.black,
            backgroundColor: AppColors.white,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.huge,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSizes.lg,
                crossAxisSpacing: AppSizes.md,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _ProductTile(product: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});
  final ProductCard product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: product.productId),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: product.imageUrl.isEmpty
                        ? Container(color: AppColors.heroPanel)
                        : Image.network(
                            resolveImageUrl(product.imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: AppColors.heroPanel),
                          ),
                  ),
                  if (product.discountPct > 0)
                    Positioned(
                      top: AppSizes.sm,
                      left: AppSizes.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                          vertical: AppSizes.xs,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.brand,
                          shape: AppShapes.squircle(AppSizes.radiusSm),
                        ),
                        child: Text(
                          '${product.discountPct}% off',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
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
          if (product.ratingCountRaw > 0) ...[
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.xs, vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: AppSizes.xs),
                      const Icon(Icons.star_rounded,
                          color: AppColors.white, size: 9),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.xs),
                Text(
                  '(${product.ratingCount})',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.price,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (product.originalPrice.isNotEmpty) ...[
                const SizedBox(width: AppSizes.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    product.originalPrice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      decoration: TextDecoration.lineThrough,
                    ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_rounded,
              size: AppSizes.iconHuge,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'Nothing here yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Products you open will show up here so you can\n'
              'find your way back to them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSizes.lg,
        crossAxisSpacing: AppSizes.md,
        childAspectRatio: 0.66,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
              child: Container(color: AppColors.surfaceTint),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          const AppShimmerLine(widthFactor: 0.85, height: AppSizes.md),
          const SizedBox(height: AppSizes.xs),
          const AppShimmerLine(widthFactor: 0.5, height: AppSizes.md),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.error),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.md),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
