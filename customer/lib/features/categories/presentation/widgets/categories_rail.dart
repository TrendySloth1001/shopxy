import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/categories/domain/entities/category.dart';
import 'package:shopxy_customer/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy_customer/features/categories/presentation/pages/category_detail_page.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/category_image.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Horizontal "Shop by category" rail rendered just under the home
/// top bar. Draws the canonical taxonomy parents, plus a trailing
/// "All" puck that opens the full categories grid.
///
/// Pure consumer of [CategoriesProvider] — load is fired in main.dart
/// at app boot, so the first paint typically lands hot.
class CategoriesRail extends StatelessWidget {
  const CategoriesRail({super.key});

  @override
  Widget build(BuildContext context) {
    final tree = context.watch<CategoriesProvider>().tree;
    if (tree.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: SizedBox(
        height: 102,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          itemCount: tree.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: AppSizes.lg),
          itemBuilder: (context, i) {
            if (i == tree.length) {
              return _AllPuck(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesPage()),
                ),
              );
            }
            final node = tree[i];
            return _CategoryPuck(
              category: node.category,
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

class _CategoryPuck extends StatelessWidget {
  const _CategoryPuck({required this.category, required this.onTap});
  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: CategoryImage(category: category),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllPuck extends StatelessWidget {
  const _AllPuck({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surfaceTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.apps_rounded, color: AppColors.black),
            ),
            const SizedBox(height: 6),
            const Text(
              'All',
              style: TextStyle(
                color: AppColors.black,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
