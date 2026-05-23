import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/presentation/widgets/catalog_product_thumbnail.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/catalog/presentation/pages/cart_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  CatalogProduct? _product;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await context
          .read<CatalogRemoteDataSource>()
          .product(widget.productId);
      if (mounted) {
        setState(() {
          _product = p;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _ProductBody(product: _product!),
      bottomNavigationBar: _product == null ? null : _BottomBar(product: _product!),
    );
  }
}

class _ProductBody extends StatelessWidget {
  const _ProductBody({required this.product});
  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, c) => CatalogProductThumbnail(
              product: product,
              size: c.maxWidth,
              cornerRadius: 0,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSizes.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${AppStrings.currencySymbol}${product.sellingPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandStrong,
                    ),
                  ),
                  if (product.isDiscounted) ...[
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      '${AppStrings.currencySymbol}${product.mrp.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                product.inStock
                    ? '${product.stockQuantity.toStringAsFixed(0)} ${product.unit} in stock'
                    : AppStrings.outOfStock,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: product.inStock ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (product.description != null && product.description!.isNotEmpty) ...[
                const SizedBox(height: AppSizes.lg),
                Text(
                  product.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (product.categoryName != null) ...[
                const SizedBox(height: AppSizes.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.xs,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.surfaceTint,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Text(
                    product.categoryName!,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.product});
  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final line = cart.lineFor(product.id);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            if (line != null) ...[
              Container(
                decoration: ShapeDecoration(
                  color: AppColors.brand,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded,
                          color: AppColors.white),
                      onPressed: () => context
                          .read<CartProvider>()
                          .setQuantity(product.id, line.quantity - 1),
                    ),
                    Text(
                      line.quantity % 1 == 0
                          ? line.quantity.toInt().toString()
                          : line.quantity.toStringAsFixed(2),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.white),
                      onPressed: () => context
                          .read<CartProvider>()
                          .setQuantity(product.id, line.quantity + 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartPage()),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text(AppStrings.cart),
                ),
              ),
            ] else
              Expanded(
                child: FilledButton(
                  onPressed: product.inStock
                      ? () => context.read<CartProvider>().add(product)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    product.inStock
                        ? AppStrings.addToCart
                        : AppStrings.outOfStock,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
