import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';
import 'package:shopxy_customer/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy_customer/features/categories/presentation/pages/category_detail_page.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/category_image.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class CategoriesRail extends StatelessWidget {
  const CategoriesRail({super.key});

  static const double _thumb = AppSizes.iconXl;

  static const double _chipHeight = _thumb + AppSizes.md;

  @override
  Widget build(BuildContext context) {
    final tree = context.watch<CategoriesProvider>().tree;
    if (tree.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: SizedBox(
        height: _chipHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          itemCount: tree.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
          itemBuilder: (context, i) {
            if (i == tree.length) {
              return _CategoryChip.all(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesPage()),
                ),
              );
            }
            final node = tree[i];
            return _CategoryChip(
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap})
    : label = null;

  const _CategoryChip.all({required this.onTap})
    : category = null,
      label = 'All';

  final Category? category;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const d = CategoriesRail._thumb;
    final Widget leading = category != null
        ? ClipOval(
            child: SizedBox(
              width: d,
              height: d,
              child: CategoryImage(category: category!),
            ),
          )
        : Container(
            width: d,
            height: d,
            decoration: const BoxDecoration(
              color: AppColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AppIcon(
              AppIcons.appsRounded,
              color: AppColors.black,
              size: AppSizes.iconMd,
            ),
          );

    return Material(
      color: AppColors.canvas,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: const BorderSide(color: AppColors.hairline, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.xs,
            AppSizes.xs,
            AppSizes.md,
            AppSizes.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: AppSizes.sm),
              Text(
                category?.name ?? label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
