import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_product_carousel.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// "See all" destination for a home-feed product carousel. Renders the
/// section's full product list (already loaded into the feed by the
/// home endpoint — typically 12–36 items) in a 2-column grid using the
/// same tile widget the carousel uses, so the visual stays identical.
///
/// This avoids the previous behavior where every carousel arrow opened
/// the search page; instead the user lands on a focused view of the
/// section they actually tapped.
class SectionProductsPage extends StatelessWidget {
  const SectionProductsPage({
    super.key,
    required this.title,
    required this.products,
    this.eyebrow,
  });

  final String title;
  final String? eyebrow;
  final List<ProductCard> products;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (eyebrow != null)
              Text(
                eyebrow!,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1,
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
      body: products.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.xl),
                child: Text(
                  'Nothing to show here right now.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                AppSizes.huge,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSizes.lg,
                crossAxisSpacing: AppSizes.md,
                // Tile is image (square) + 2 lines name + price + bank
                // offer line ≈ 1 / 1.55 aspect.
                childAspectRatio: 0.62,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => HomeProductTile(
                product: products[i],
                width: null,
              ),
            ),
    );
  }
}
