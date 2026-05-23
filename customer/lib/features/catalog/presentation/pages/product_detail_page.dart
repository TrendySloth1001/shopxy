import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/presentation/widgets/catalog_product_thumbnail.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/catalog/presentation/pages/cart_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/wishlist/presentation/widgets/wishlist_heart_button.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_quantity_stepper.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

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
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        elevation: 0,
        title: const Text('Product'),
        actions: [
          if (_product != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.sm),
              child: WishlistHeartButton.flat(productId: _product!.id),
            ),
        ],
      ),
      body: _loading
          ? const _LoadingState()
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _ProductBody(product: _product!),
      bottomNavigationBar:
          _product == null ? null : _BottomBar(product: _product!),
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
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppPriceText.precise(
                    product.sellingPrice,
                    style: theme.textTheme.headlineSmall,
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w800,
                  ),
                  if (product.isDiscounted) ...[
                    const SizedBox(width: AppSizes.sm),
                    AppPriceText.precise(
                      product.mrp,
                      strikethrough: true,
                      style: theme.textTheme.bodyMedium,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              _StockBadge(product: product),
              if (product.description != null &&
                  product.description!.isNotEmpty) ...[
                const SizedBox(height: AppSizes.lg),
                Text(
                  product.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                    height: 1.5,
                  ),
                ),
              ],
              if (product.categoryName != null) ...[
                const SizedBox(height: AppSizes.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.xs + 2,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.surfaceTint,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Text(
                    product.categoryName!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w700,
                    ),
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

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});
  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inStock = product.inStock;
    final bg = inStock ? AppColors.successSoft : AppColors.errorSoft;
    final fg = inStock ? AppColors.success : AppColors.error;
    final icon = inStock
        ? Icons.check_circle_rounded
        : Icons.remove_circle_outline_rounded;
    final label = inStock
        ? '${product.stockQuantity.toStringAsFixed(0)} ${product.unit} in stock'
        : AppStrings.outOfStock;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.xs + 2,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSizes.xs + 2),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
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
              AppQuantityStepper(
                quantity: line.quantity.toInt(),
                onChanged: (q) => context
                    .read<CartProvider>()
                    .setQuantity(product.id, q.toDouble()),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: AppButton.primary(
                  label: AppStrings.cart,
                  icon: Icons.shopping_bag_rounded,
                  fullWidth: true,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartPage()),
                  ),
                ),
              ),
            ] else
              Expanded(
                child: AppButton.primary(
                  label: product.inStock
                      ? AppStrings.addToCart
                      : AppStrings.outOfStock,
                  icon: product.inStock ? Icons.add_shopping_cart_rounded : null,
                  fullWidth: true,
                  onPressed: product.inStock
                      ? () => context.read<CartProvider>().add(product)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppShimmerBox(height: 360, radius: 0),
        Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppShimmerLine(widthFactor: 0.7, height: 22),
              SizedBox(height: 12),
              AppShimmerLine(widthFactor: 0.3, height: 28),
              SizedBox(height: 16),
              AppShimmerLine(widthFactor: 1.0, height: 14),
              SizedBox(height: 6),
              AppShimmerLine(widthFactor: 0.9, height: 14),
              SizedBox(height: 6),
              AppShimmerLine(widthFactor: 0.85, height: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 40,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.md),
            AppButton.secondary(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () => onRetry(),
            ),
          ],
        ),
      ),
    );
  }
}
