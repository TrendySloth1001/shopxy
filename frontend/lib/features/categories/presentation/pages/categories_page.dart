import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/pages/category_products_page.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CategoriesProvider>().loadTree();
    });
  }

  @override
  void dispose() {
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<CategoriesProvider>();
    final tree = provider.tree;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.categoriesTitle),
      body: provider.isLoading && tree.isEmpty
          ? const _CategoriesGridSkeleton()
          : tree.isEmpty
          ? EmptyState.line(
              kind: LineArt.productTag,
              title: l10n.categoriesEmptyTitle,
              subtitle: l10n.categoriesEmptyHint,
            )
          : RefreshIndicator(
              onRefresh: () => provider.loadTree(),
              color: AppColors.black,
              backgroundColor: AppColors.surface,
              child: GridView.builder(
                controller: _scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  AppSizes.md,
                  AppSizes.md + FloatingAppBar.contentTopInset(context),
                  AppSizes.md,
                  AppSizes.md,
                ),
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
                        builder: (_) =>
                            CategoryProductsPage(category: node.category),
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
    final labelStyle = theme.textTheme.bodyMedium?.semibold;
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusButton),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusButton),
              child: SizedBox(
                width: double.infinity,
                child: _CategoryImage(category: category),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          SizedBox(
            height: _twoLineHeight(context, labelStyle),
            child: Text(
              category.name,
              style: labelStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

double _twoLineHeight(BuildContext context, TextStyle? style) {
  final fontSize = style?.fontSize ?? 14;
  final lineHeight = style?.height ?? 1.3;
  final scaled = MediaQuery.textScalerOf(context).scale(fontSize);
  return scaled * lineHeight * 2;
}

class _CategoriesGridSkeleton extends StatelessWidget {
  const _CategoriesGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSizes.md,
        crossAxisSpacing: AppSizes.md,
        childAspectRatio: 0.82,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => const _CategoryCardSkeleton(),
    );
  }
}

class _CategoryCardSkeleton extends StatelessWidget {
  const _CategoryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppShimmerBox(
            width: double.infinity,
            height: double.infinity,
            radius: AppSizes.radiusButton,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        const AppShimmerLine(widthFactor: 1.0, height: AppSizes.sm),
        const SizedBox(height: AppSizes.xs),
        const AppShimmerLine(widthFactor: 0.7, height: AppSizes.sm),
      ],
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final url = category.imageUrl;
    final fallback = Container(
      color: AppColors.heroPanel,
      alignment: Alignment.center,
      child: AppIcon(
        resolveCategoryIcon(category.iconName),
        color: AppColors.black,
        size: AppSizes.iconLg,
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: AppColors.heroPanel),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
