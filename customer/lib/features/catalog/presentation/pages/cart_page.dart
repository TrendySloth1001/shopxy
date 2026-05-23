import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/router/app_shell.dart';
import 'package:shopxy_customer/features/catalog/presentation/widgets/catalog_product_thumbnail.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/cart_item.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_quantity_stepper.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/widgets/app_text_field.dart';

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
    final ordersProvider = context.read<OrdersProvider>();

    final orderId = await cart.placeOrder();
    if (!context.mounted) return;

    if (orderId == null) {
      showAppSnackbar(
        context,
        message: cart.error ?? AppStrings.error,
        tone: AppSnackbarTone.error,
      );
      return;
    }

    unawaited(ordersProvider.load());

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: orderId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: AppStrings.yourCart),
      body: cart.isEmpty
          ? const _EmptyCart()
          : _Body(note: _note, lines: cart.lines),
      bottomNavigationBar:
          cart.isEmpty ? null : _CheckoutBar(cart: cart, onCheckout: _checkout),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart, required this.onCheckout});
  final CartProvider cart;
  final Future<void> Function(BuildContext) onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.md,
        ),
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
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppPriceText.precise(
                    cart.totalPrice,
                    style: theme.textTheme.titleLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ],
              ),
            ),
            AppButton.primary(
              label: AppStrings.checkout,
              icon: Icons.arrow_forward_rounded,
              isLoading: cart.isPlacing,
              onPressed: () => onCheckout(context),
            ),
          ],
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
          child: AppTextField(
            controller: note,
            label: AppStrings.orderNotePlaceholder,
            hint: 'Anything the shop should know?',
            minLines: 2,
            maxLines: 4,
            maxLength: 240,
            textCapitalization: TextCapitalization.sentences,
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
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          children: [
            CatalogProductThumbnail(product: line.product, size: 60),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      AppPriceText.precise(
                        line.product.sellingPrice,
                        style: theme.textTheme.bodySmall,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                      Text(
                        ' · ${line.product.unit}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  AppQuantityStepper(
                    dense: true,
                    quantity: line.quantity.toInt(),
                    onChanged: (q) => context
                        .read<CartProvider>()
                        .setQuantity(line.product.id, q.toDouble()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppPriceText.precise(
                  line.lineTotal,
                  style: theme.textTheme.bodyMedium,
                  fontWeight: FontWeight.w800,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.muted,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove',
                  onPressed: () =>
                      context.read<CartProvider>().remove(line.product.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Baymard rule (DESIGN.md #11): empty cart shows "Continue shopping",
/// not "Go back". The CTA flips to the Browse tab so the user lands
/// on something useful, not on the previous route.
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusLg),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              AppStrings.emptyCart,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              AppStrings.emptyCartHint,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.xl),
            AppButton.primary(
              label: 'Continue shopping',
              icon: Icons.grid_view_rounded,
              onPressed: () {
                CustomerShellScope.of(context)
                    ?.select(CustomerShellTab.browse.index);
                Navigator.maybePop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
