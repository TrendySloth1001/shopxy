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
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSizes.lg,
                  crossAxisSpacing: AppSizes.md,
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

class _CategoryTileSkeleton extends StatelessWidget {
  const _CategoryTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: AppShimmerBox(
            height: double.infinity,
            radius: AppSizes.radiusButton,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        const AppShimmerLine(widthFactor: 0.9, height: AppSizes.md),
        const SizedBox(height: AppSizes.xs),
        const AppShimmerLine(widthFactor: 0.6, height: AppSizes.md),
        const SizedBox(height: AppSizes.xs),
        const AppShimmerLine(widthFactor: 0.45, height: AppSizes.sm),
      ],
    );
  }
}

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
            style: theme.textTheme.bodyMedium?.bold,
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
