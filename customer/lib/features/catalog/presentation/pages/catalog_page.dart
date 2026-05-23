import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/catalog/presentation/widgets/catalog_product_thumbnail.dart';
import 'package:shopxy_customer/features/catalog/presentation/pages/cart_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
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
      appBar: AppBar(
        title: const Text(AppStrings.browseTitle),
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
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: AppStrings.searchProducts,
                prefixIcon: Icon(Icons.search_rounded),
              ),
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
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        children: [
          _Chip(
            label: 'All',
            icon: Icons.apps_rounded,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final c in categories)
            _Chip(
              label: c.name,
              icon: resolveCategoryIcon(c.iconName),
              selected: selected == c.id,
              onTap: () => onSelect(c.id),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.black;
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sm),
      child: Material(
        color: selected ? AppColors.black : AppColors.surfaceTint,
        shape: AppShapes.squircle(AppSizes.radiusFull),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusFull),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      return const Center(child: CircularProgressIndicator());
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
                // LayoutBuilder so the thumbnail's monogram letter
                // scales with the actual rendered card size, not a
                // fixed magic number — looks the same on a tight
                // 2-column phone grid as on a wider tablet grid.
                child: LayoutBuilder(
                  builder: (context, c) => CatalogProductThumbnail(
                    product: product,
                    size: c.maxWidth,
                    cornerRadius: 0,
                  ),
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
                  Text(
                    '${AppStrings.currencySymbol}${product.sellingPrice.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandStrong,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  SizedBox(
                    height: 32,
                    child: line == null
                        ? FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size.fromHeight(32),
                              backgroundColor: product.inStock
                                  ? AppColors.brandSoft
                                  : AppColors.surfaceTint,
                              foregroundColor: product.inStock
                                  ? AppColors.brandStrong
                                  : AppColors.muted,
                            ),
                            onPressed: product.inStock
                                ? () => context.read<CartProvider>().add(product)
                                : null,
                            child: Text(
                              product.inStock
                                  ? AppStrings.addToCart
                                  : AppStrings.outOfStock,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : _QtyStepper(
                            quantity: line.quantity,
                            onChanged: (q) => context
                                .read<CartProvider>()
                                .setQuantity(product.id, q),
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

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.quantity, required this.onChanged});
  final double quantity;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.brand,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.remove_rounded,
            onTap: () => onChanged(quantity - 1),
          ),
          Expanded(
            child: Center(
              child: Text(
                quantity % 1 == 0
                    ? quantity.toInt().toString()
                    : quantity.toStringAsFixed(2),
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          _IconBtn(
            icon: Icons.add_rounded,
            onTap: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 16, color: AppColors.white),
      ),
    );
  }
}
