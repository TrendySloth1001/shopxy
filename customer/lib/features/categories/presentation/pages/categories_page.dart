import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';
import 'package:shopxy_customer/features/categories/presentation/pages/category_detail_page.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/category_image.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

/// Customer landing for "All categories". Big image grid; tap drills
/// down into a [CategoryDetailPage] that lists subcategories + the
/// merged product feed for the whole parent bucket.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CategoriesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoriesProvider>();
    final tree = provider.tree;

    return Scaffold(
      appBar: AppBar(title: const Text('All categories')),
      body: provider.isLoading && tree.isEmpty
          ? const _CategoryGridSkeleton()
          : tree.isEmpty
              ? const Center(child: Text('No categories yet'))
              : RefreshIndicator(
                  onRefresh: () => provider.load(force: true),
                  color: AppColors.black,
                  backgroundColor: AppColors.white,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSizes.lg,
                      crossAxisSpacing: AppSizes.md,
                      // Tile has a square thumb + 2-line name + "N subs"
                      // chip. 0.82 clipped the chip at default text scale;
                      // 0.7 gives every tile enough vertical room.
                      childAspectRatio: 0.7,
                    ),
                    itemCount: tree.length,
                    itemBuilder: (context, index) {
                      final node = tree[index];
                      return _CategoryTile(
                        category: node.category,
                        childCount: node.children.length,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryDetailPage(node: node),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

/// 3-column grid of 6 skeleton tiles — mirrors the real [GridView.builder]
/// layout while [CategoriesProvider.isLoading] is true and the tree is empty.
class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSizes.lg,
        crossAxisSpacing: AppSizes.md,
        childAspectRatio: 0.7,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => const _CategoryTileSkeleton(),
    );
  }
}

/// Single skeleton tile that mirrors [_CategoryTile]:
///   • square [AppShimmerBox]  — category image placeholder
///   • two [AppShimmerLine]s   — 2-line category name placeholder
///   • one narrower [AppShimmerLine] — subcategory count placeholder
class _CategoryTileSkeleton extends StatelessWidget {
  const _CategoryTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Square thumb — AspectRatio 1:1, same corner radius as the real tile.
        AspectRatio(
          aspectRatio: 1,
          child: AppShimmerBox(
            height: double.infinity,
            radius: AppSizes.radiusButton,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        // First name line (full width).
        const AppShimmerLine(widthFactor: 0.9, height: AppSizes.md),
        const SizedBox(height: AppSizes.xs),
        // Second name line (slightly shorter to feel natural).
        const AppShimmerLine(widthFactor: 0.6, height: AppSizes.md),
        const SizedBox(height: AppSizes.xs),
        // Subcategory count line — narrower, matches bodySmall visual weight.
        const AppShimmerLine(widthFactor: 0.45, height: AppSizes.sm),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.childCount,
    required this.onTap,
  });
  final Category category;
  final int childCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusButton),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusButton),
              child: CategoryImage(category: category),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            category.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (childCount > 0)
            Text(
              '$childCount subcategories',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}
