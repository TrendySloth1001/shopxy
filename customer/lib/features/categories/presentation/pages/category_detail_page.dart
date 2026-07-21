import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';
import 'package:shopxy_customer/features/categories/presentation/pages/category_products_page.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/category_image.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

/// Subcategory drill-down. Two pieces:
///   1. A hero card for the parent — tap pushes the rolled-up products
///      page (parent slug → backend rolls up children).
///   2. A list of child chips/tiles. Tap loads only that subcategory.
///
/// Pure-presentational — the tree comes pre-loaded in the provider so
/// the page doesn't fire a network request.
class CategoryDetailPage extends StatelessWidget {
  const CategoryDetailPage({super.key, required this.node});
  final CategoryNode node;

  void _open(BuildContext context, Category category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = node.children;
    return Scaffold(
      appBar: AppBar(title: Text(node.category.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          InkWell(
            onTap: () => _open(context, node.category),
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusLg),
            child: ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusLg),
              child: AspectRatio(
                aspectRatio: 1.9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CategoryImage(category: node.category),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.black.withValues(alpha: 0.54),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSizes.lg,
                      right: AppSizes.lg,
                      bottom: AppSizes.md,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shop all in ${node.category.name}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Row(
                            children: [
                              Text(
                                'Across every subcategory →',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: AppSizes.xl),
            Text('Subcategories', style: theme.textTheme.titleSmall?.bold),
            const SizedBox(height: AppSizes.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSizes.lg,
                crossAxisSpacing: AppSizes.md,
                childAspectRatio: 0.7,
              ),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return InkWell(
                  onTap: () => _open(context, child.category),
                  borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: AppShapes.squircleRadius(
                            AppSizes.radiusMd,
                          ),
                          child: CategoryImage(category: child.category),
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        child.category.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
