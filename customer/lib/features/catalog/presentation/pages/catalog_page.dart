import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/catalog/presentation/widgets/catalog_product_thumbnail.dart';
import 'package:shopxy_customer/features/catalog/presentation/pages/cart_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:shopxy_customer/features/wishlist/presentation/widgets/wishlist_heart_button.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/widgets/app_app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_filter_chip.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_quantity_stepper.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/widgets/app_text_field.dart';
import 'package:shopxy_customer/shared/widgets/category_icon_catalog.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<CatalogProvider>();
      p.load();
      p.loadCategories();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CatalogProvider>();
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppAppBar(
        title: AppStrings.browseTitle,
        actions: [_CartButton(itemCount: cart.totalItems)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: AppTextField(
              controller: _searchCtrl,
              hint: AppStrings.searchProducts,
              prefixIcon: Icons.search_rounded,
              onChanged: p.setSearch,
            ),
          ),
          if (p.categories.isNotEmpty)
            _CategoryStrip(
              categories: p.categories,
              selected: p.categoryId,
              onSelect: p.setCategory,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => p.load(refresh: true),
              color: AppColors.brand,
              child: _Body(provider: p),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.itemCount});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined),
          tooltip: AppStrings.cart,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          ),
        ),
        if (itemCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              alignment: Alignment.center,
              child: Text(
                '$itemCount',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });
  final List<CatalogCategory> categories;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        itemCount: categories.length + 1,
        separatorBuilder: (_, index) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (_, i) {
          if (i == 0) {
            return AppFilterChip(
              label: 'All',
              icon: Icons.apps_rounded,
              selected: selected == null,
              onTap: () => onSelect(null),
            );
          }
          final c = categories[i - 1];
          return AppFilterChip(
            label: c.name,
            icon: resolveCategoryIcon(c.iconName),
            selected: selected == c.id,
            onTap: () => onSelect(c.id),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});
  final CatalogProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.products.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppSizes.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSizes.md,
          crossAxisSpacing: AppSizes.md,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, index) => const _SkeletonCard(),
      );
    }
    if (provider.error != null && provider.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Text(provider.error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (provider.products.isEmpty) {
      return const Center(child: Text('No products found.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSizes.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSizes.md,
        crossAxisSpacing: AppSizes.md,
        childAspectRatio: 0.72,
      ),
      itemCount: provider.products.length,
      itemBuilder: (_, i) => _ProductCard(product: provider.products[i]),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: AppShimmerBox(
              height: double.infinity,
              radius: AppSizes.radiusLg,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppShimmerLine(widthFactor: 0.8, height: 10),
                SizedBox(height: 6),
                AppShimmerLine(widthFactor: 0.5, height: 14),
                SizedBox(height: 8),
                AppShimmerLine(widthFactor: 1.0, height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartProvider>();
    final line = cart.lineFor(product.id);

    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: product.id),
        ),
      ),
      child: Container(
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
                child: Stack(
                  children: [
                    // LayoutBuilder so the thumbnail's monogram letter
                    // scales with the actual rendered card size, not
                    // a magic number — looks the same on a tight
                    // 2-col phone grid as on a wider tablet grid.
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, c) => CatalogProductThumbnail(
                          product: product,
                          size: c.maxWidth,
                          cornerRadius: 0,
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppSizes.xs,
                      right: AppSizes.xs,
                      child: WishlistHeartButton(productId: product.id),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  AppPriceText.compact(
                    product.sellingPrice,
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w800,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: !product.inStock
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sm,
                              vertical: 6,
                            ),
                            decoration: ShapeDecoration(
                              color: AppColors.surfaceTint,
                              shape: AppShapes.squircle(AppSizes.radiusFull),
                            ),
                            child: const Text(
                              AppStrings.outOfStock,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : AppQuantityStepper(
                            dense: true,
                            quantity:
                                line == null ? 0 : line.quantity.toInt(),
                            addLabel: AppStrings.addToCart,
                            onChanged: (q) {
                              final cart = context.read<CartProvider>();
                              if (q == 0) {
                                cart.setQuantity(product.id, 0);
                              } else if (line == null) {
                                cart.add(product);
                              } else {
                                cart.setQuantity(product.id, q.toDouble());
                              }
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

