import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/catalog/presentation/widgets/catalog_product_thumbnail.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/cart_item.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _note.text = context.read<CartProvider>().note;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _checkout(BuildContext context) async {
    final cart = context.read<CartProvider>();
    cart.setNote(_note.text);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ordersProvider = context.read<OrdersProvider>();

    final orderId = await cart.placeOrder();
    if (!mounted) return;

    if (orderId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(cart.error ?? AppStrings.error)),
      );
      return;
    }

    // Refresh the orders list so "My orders" shows the new row when the
    // user lands on it. Don't block on this — fire and forget.
    unawaited(ordersProvider.load());

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: orderId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.yourCart)),
      body: cart.isEmpty ? const _EmptyCart() : _Body(note: _note, lines: cart.lines),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.estimatedTotal,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                          Text(
                            '${AppStrings.currencySymbol}${cart.totalPrice.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: cart.isPlacing ? null : () => _checkout(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        minimumSize: const Size(160, 48),
                      ),
                      child: cart.isPlacing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(AppStrings.checkout),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.note, required this.lines});
  final TextEditingController note;
  final List<CartItem> lines;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      children: [
        for (final line in lines) _CartRow(line: line),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.xl,
            AppSizes.lg,
            AppSizes.lg,
          ),
          child: TextField(
            controller: note,
            decoration: const InputDecoration(
              hintText: AppStrings.orderNotePlaceholder,
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.line});
  final CartItem line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          CatalogProductThumbnail(
            product: line.product,
            size: 60,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${AppStrings.currencySymbol}${line.product.sellingPrice.toStringAsFixed(2)} · ${line.product.unit}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.xs),
                Container(
                  decoration: ShapeDecoration(
                    color: AppColors.surfaceTint,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        icon: const Icon(Icons.remove_rounded),
                        onPressed: () => context
                            .read<CartProvider>()
                            .setQuantity(line.product.id, line.quantity - 1),
                      ),
                      Text(
                        line.quantity % 1 == 0
                            ? line.quantity.toInt().toString()
                            : line.quantity.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () => context
                            .read<CartProvider>()
                            .setQuantity(line.product.id, line.quantity + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${AppStrings.currencySymbol}${line.lineTotal.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                onPressed: () =>
                    context.read<CartProvider>().remove(line.product.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusLg),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 48, color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              AppStrings.emptyCart,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              AppStrings.emptyCartHint,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

