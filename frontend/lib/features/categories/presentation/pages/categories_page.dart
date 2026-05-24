import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/pages/category_products_page.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

/// Read-only browse of the canonical taxonomy. Merchants don't manage
/// categories any more — the seed lives in the backend manifest. This
/// page just lets the merchant browse "my products by category".
/// Tapping a tile drops into [CategoryProductsPage] which lists the
/// merchant's own products in that bucket.
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
      context.read<CategoriesProvider>().loadTree();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoriesProvider>();
    final tree = provider.tree;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navCategories)),
      body: provider.isLoading && tree.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tree.isEmpty
              ? EmptyState.line(
                  kind: LineArt.productTag,
                  title: AppStrings.noCategories,
                  subtitle: AppStrings.noCategoriesHint,
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadTree(),
                  color: AppColors.black,
                  backgroundColor: AppColors.white,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSizes.md,
                      crossAxisSpacing: AppSizes.md,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: tree.length,
                    itemBuilder: (context, index) {
                      final node = tree[index];
                      return _CategoryCard(
                        category: node.category,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryProductsPage(
                              category: node.category,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});
  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _CategoryImage(category: category),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            category.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Category artwork. Falls back to the iconName-derived icon over a
/// tinted background when the network image fails or no URL is set.
class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final url = category.imageUrl;
    final fallback = Container(
      color: AppColors.surfaceTint,
      alignment: Alignment.center,
      child: Icon(
        resolveCategoryIcon(category.iconName),
        color: AppColors.black,
        size: 28,
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: AppColors.surfaceTint),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
