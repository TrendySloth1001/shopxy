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
        child: brands.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSizes.xl),
                    child: Text(
                      'No spotlights running right now.',
                      style: TextStyle(color: AppColors.muted),
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
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F757),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        brand.dealLabel,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      brand.brand,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    if (brand.subtitle.isNotEmpty)
                      Text(
                        brand.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
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
