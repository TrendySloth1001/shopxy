import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/router/app_shell.dart';
import 'package:shopxy_customer/features/catalog/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/widgets/catalog_product_thumbnail.dart';
import 'package:shopxy_customer/features/wishlist/data/datasources/wishlist_remote_data_source.dart';
import 'package:shopxy_customer/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:shopxy_customer/features/wishlist/presentation/widgets/wishlist_heart_button.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

/// Saved-for-later list. Pushed from the Home page's "Saved" tile and
/// from the profile page (not yet wired). Empty state guides the user
/// back to Browse — explicit CTA per DESIGN.md #5.
class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WishlistProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WishlistProvider>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'Saved'),
      body: RefreshIndicator(
        onRefresh: () => p.load(),
        color: AppColors.brand,
        child: _Body(provider: p),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});
  final WishlistProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.entries.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        itemCount: 5,
        separatorBuilder: (_, index) =>
            const SizedBox(height: AppSizes.md),
        itemBuilder: (_, index) => const _SkeletonRow(),
      );
    }
    if (provider.error != null && provider.entries.isEmpty) {
      return _ErrorBlock(message: provider.error!, onRetry: provider.load);
    }
    if (provider.entries.isEmpty) {
      return const _EmptyState();
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      itemCount: provider.entries.length,
      separatorBuilder: (_, index) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, i) => _Row(entry: provider.entries[i]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});
  final WishlistEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = entry.product;
    final shape = AppShapes.squircle(
      AppSizes.radiusMd,
      side: const BorderSide(color: AppColors.hairline),
    );
    return Material(
      color: AppColors.white,
      shape: shape,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(productId: p.id),
          ),
        ),
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              CatalogProductThumbnail(product: p, size: 64),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.categoryName ?? p.unit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    AppPriceText.compact(p.sellingPrice),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              WishlistHeartButton(productId: p.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Row(
        children: const [
          AppShimmerBox(width: 64, height: 64, radius: 12),
          SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.8, height: 12),
                SizedBox(height: 6),
                AppShimmerLine(widthFactor: 0.4, height: 10),
                SizedBox(height: 8),
                AppShimmerLine(widthFactor: 0.3, height: 12),
              ],
            ),
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
    return ListView(
      padding: const EdgeInsets.all(AppSizes.xl),
      children: [
        const SizedBox(height: AppSizes.huge),
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: AppColors.accentRoseSoft,
            shape: AppShapes.squircle(AppSizes.radiusLg),
          ),
          child: const Icon(
            Icons.favorite_rounded,
            size: 36,
            color: AppColors.accentRose,
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Text(
          'Nothing saved yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Tap the heart on any product to save it here for later.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.xl),
        Align(
          alignment: Alignment.center,
          child: AppButton.primary(
            label: 'Browse products',
            icon: Icons.grid_view_rounded,
            onPressed: () {
              CustomerShellScope.of(context)
                  ?.select(CustomerShellTab.browse.index);
              Navigator.maybePop(context);
            },
          ),
        ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

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
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.md),
            AppButton.secondary(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () => onRetry(),
            ),
          ],
        ),
      ),
    );
  }
}
