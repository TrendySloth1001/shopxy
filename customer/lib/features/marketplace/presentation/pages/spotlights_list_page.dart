import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

/// Reachable from the home "Brands in spotlight → View all" affordance.
/// Renders every active brand spotlight in a tall single-column list so
/// the user can browse all of them at once — taps deep-link to that
/// shop's `ShopProfilePage`.
class SpotlightsListPage extends StatelessWidget {
  const SpotlightsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<HomeFeedProvider>();
    final brands = feed.feed.brandSpotlights;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        title: const Text('Brands in spotlight'),
      ),
      body: RefreshIndicator(
        onRefresh: () => feed.refresh(),
        child: feed.isLoading && brands.isEmpty
            ? ListView.separated(
                padding: const EdgeInsets.all(AppSizes.lg),
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
                itemBuilder: (_, _) => const _SpotlightCardSkeleton(),
              )
            : brands.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
                        child: Text(
                          'No spotlights running right now.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    itemCount: brands.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
                    itemBuilder: (_, i) => _Card(brand: brands[i]),
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton card — mirrors the 16:9 AspectRatio layout of _Card
// ---------------------------------------------------------------------------
class _SpotlightCardSkeleton extends StatelessWidget {
  const _SpotlightCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image area — fills the whole card
            AppShimmerBox(
              width: double.infinity,
              height: double.infinity,
              radius: AppSizes.radiusMd,
            ),
            // Text overlay at the bottom, same padding as _Card
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Deal label chip
                  AppShimmerBox(
                    width: 72,
                    height: 18,
                    radius: 2,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  // Brand name
                  AppShimmerLine(widthFactor: 0.55, height: 18),
                  const SizedBox(height: AppSizes.xs),
                  // Subtitle
                  AppShimmerLine(widthFactor: 0.40, height: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.brand});
  final BrandSpotlight brand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: brand.shopSlug == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShopProfilePage(slug: brand.shopSlug!),
                ),
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (brand.imageUrl.isNotEmpty)
                NetworkImageBox(
                  url: resolveImageUrl(brand.imageUrl),
                  placeholderColor: brand.bgColor,
                )
              else
                Container(color: brand.bgColor),
              Container(
                decoration: ShapeDecoration(
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm, vertical: AppSizes.xs),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F757),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        brand.dealLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.black,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      brand.brand,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                    ),
                    if (brand.subtitle.isNotEmpty)
                      Text(
                        brand.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
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
