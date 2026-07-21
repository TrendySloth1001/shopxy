import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/features/cart/presentation/pages/checkout_page.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/cart_item.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_quantity_stepper.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/widgets/shop_chip.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

/// Cart page. Rewritten from zero (May 2026, build3) because earlier
/// iterations collapsed on certain devices — the AppBar disappeared and
/// the bottom CTA floated into the body. This version uses an explicit
/// `Column { Header, Expanded(Body), Footer }` layout, no Scaffold
/// `appBar`/`bottomNavigationBar` slots at all — guarantees the three
/// regions can never swap places.
///
/// A small "BUILD 3" pill in the header is the visual canary: if you
/// don't see it on the device, the code on disk isn't running.
class CartPage extends StatelessWidget {
  const CartPage({super.key, this.embedded = false});

  final bool embedded;

  Future<void> _goToCheckout(BuildContext context) async {
    // Guests can browse and build a basket, but checkout needs an
    // account so we can attach the order to a user + ship to a saved
    // address. After sign-in the cart is server-merged (main.dart's
    // auth listener) so the items they just built up survive.
    final signedIn = await requireAuth(
      context,
      reason:
          'Sign in to place your order and ship it to a saved address. '
          'Your cart will be kept.',
    );
    if (!signedIn || !context.mounted) return;
    // When the cart sits inside a tab (embedded=true) the closest
    // Navigator is the AppShell's nested one. Pushing checkout onto
    // it leaves the bottom tab bar visible and traps the back gesture
    // inside the cart tab. Use the root navigator so checkout owns
    // the screen and back returns to wherever the user came from.
    Navigator.of(
      context,
      rootNavigator: embedded,
    ).push(MaterialPageRoute(builder: (_) => const CheckoutPage()));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final subtotal = cart.totalPrice;
    final mrpTotal = cart.mrpTotal;
    final savings = cart.savings;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      // Single Column inside SafeArea — header + body + footer can't
      // race for vertical space.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(itemCount: cart.lineCount, showBack: !embedded),
            Expanded(
              child: cart.isEmpty
                  ? const _EmptyCart()
                  : _Body(
                      cart: cart,
                      subtotal: subtotal,
                      mrpTotal: mrpTotal,
                      savings: savings,
                    ),
            ),
            if (!cart.isEmpty)
              _Footer(
                total: subtotal,
                savings: savings,
                isPlacing: cart.isPlacing,
                onProceed: () => _goToCheckout(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Top header bar ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.itemCount, required this.showBack});
  final int itemCount;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(bottom: BorderSide(color: AppColors.hairline, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.sm,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const AppIcon(AppIcons.arrowBackRounded),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            )
          else
            const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'My Cart',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  itemCount == 0
                      ? 'Empty for now'
                      : '$itemCount ${itemCount == 1 ? 'item' : 'items'} in your bag',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cart body ──────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.cart,
    required this.subtotal,
    required this.mrpTotal,
    required this.savings,
  });
  final CartProvider cart;
  final double subtotal;
  final double mrpTotal;
  final double savings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, AppSizes.md, 0, AppSizes.lg),
      children: [
        if (savings > 0) ...[
          _SavingsBanner(amount: savings),
          const SizedBox(height: AppSizes.md),
        ],
        const _Section(label: 'ITEMS IN YOUR BAG'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          decoration: ShapeDecoration(
            color: AppColors.white,
            shape: AppShapes.squircle(AppSizes.radiusMd),
          ),
          child: Column(
            children: [
              for (var i = 0; i < cart.lines.length; i++) ...[
                if (i != 0) const Divider(height: 1, color: AppColors.hairline),
                _CartLineRow(line: cart.lines[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        const _Section(label: 'BILL SUMMARY'),
        _BillCard(subtotal: subtotal, mrpTotal: mrpTotal, savings: savings),
        const SizedBox(height: AppSizes.lg),
        const _ReassuranceCard(),
      ],
    );
  }
}

class _SavingsBanner extends StatelessWidget {
  const _SavingsBanner({required this.amount});
  final double amount;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: ShapeDecoration(
        color: AppColors.successSoft,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.savingsOutlined,
            color: AppColors.success,
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Wrap(
              children: [
                Text(
                  'You are saving ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppPriceText.precise(
                  amount,
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  ' on this order',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.lg,
      0,
      AppSizes.lg,
      AppSizes.sm,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow({required this.line});
  final CartItem line;

  @override
  Widget build(BuildContext context) {
    final product = line.product;
    final hasDiscount = product.mrp > product.sellingPrice;
    final qty = line.quantity.toInt();
    final discountPct = hasDiscount
        ? (((product.mrp - product.sellingPrice) / product.mrp) * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(productId: product.id),
              ),
            ),
            child: ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
              child: Container(
                width: 80,
                height: 80,
                color: AppColors.heroPanel,
                child: product.imageUrl == null
                    ? const AppIcon(
                        AppIcons.imageOutlined,
                        color: AppColors.muted,
                        size: AppSizes.iconMd,
                      )
                    : NetworkImageBox(url: resolveImageUrl(product.imageUrl!)),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (product.shopName != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ShopChip(shopName: product.shopName, dense: true),
                  ),
                ],
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppPriceText.precise(
                      product.sellingPrice,
                      fontWeight: FontWeight.w800,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (hasDiscount)
                      AppPriceText.compact(
                        product.mrp,
                        color: AppColors.muted,
                        strikethrough: true,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    if (discountPct > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                          vertical: 2,
                        ),
                        decoration: ShapeDecoration(
                          color: AppColors.successSoft,
                          shape: AppShapes.squircle(AppSizes.radiusFull),
                        ),
                        child: Text(
                          '$discountPct% off',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    AppQuantityStepper(
                      dense: true,
                      quantity: qty,
                      // Cap + at the known stock so the customer isn't
                      // invited to request more than the shop can sell.
                      maxQuantity: product.stockQuantity > 0
                          ? product.stockQuantity.floor()
                          : null,
                      onChanged: (v) {
                        final result = context.read<CartProvider>().setQuantity(
                          product.id,
                          v.toDouble(),
                        );
                        if (result == AddToCartResult.capped) {
                          showAppSnackbar(
                            context,
                            message:
                                'Only ${product.stockQuantity.floor()} left in stock',
                            tone: AppSnackbarTone.info,
                          );
                        }
                      },
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        // Keep what we need for UNDO before the line is gone.
                        final removedQty = line.quantity;
                        final cart = context.read<CartProvider>();
                        cart.remove(product.id);
                        showAppSnackbar(
                          context,
                          message: 'Removed ${product.name}',
                          actionLabel: 'UNDO',
                          onAction: () =>
                              cart.add(product, quantity: removedQty),
                        );
                      },
                      borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                          vertical: AppSizes.sm,
                        ),
                        child: Text(
                          'Remove',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({
    required this.subtotal,
    required this.mrpTotal,
    required this.savings,
  });
  final double subtotal;
  final double mrpTotal;
  final double savings;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          if (savings > 0)
            _BillRow(
              label: 'Items (MRP)',
              value: mrpTotal,
              valueStrike: true,
              valueColor: AppColors.muted,
            ),
          _BillRow(label: 'Items total', value: subtotal),
          if (savings > 0)
            _BillRow(
              label: 'Product discount',
              negative: savings,
              valueColor: AppColors.success,
            ),
          const _BillRow(
            label: 'Delivery',
            valueLabel: 'FREE',
            valueColor: AppColors.success,
          ),
          const Divider(height: AppSizes.lg, color: AppColors.hairline),
          _BillRow(label: 'Cart total', value: subtotal, bold: true),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    this.value,
    this.valueLabel,
    this.valueColor,
    this.bold = false,
    this.valueStrike = false,
    this.negative,
  });
  final String label;
  final double? value;
  final String? valueLabel;
  final Color? valueColor;
  final bool bold;
  final bool valueStrike;
  final double? negative;

  @override
  Widget build(BuildContext context) {
    final col = valueColor ?? AppColors.black;
    final theme = Theme.of(context);
    Widget val;
    if (valueLabel != null) {
      val = Text(
        valueLabel!,
        style: (bold ? theme.textTheme.titleMedium : theme.textTheme.bodySmall)
            ?.copyWith(color: col, fontWeight: FontWeight.w800),
      );
    } else if (negative != null) {
      val = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '− ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
          AppPriceText.precise(
            negative!,
            color: col,
            fontWeight: FontWeight.w800,
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    } else {
      val = AppPriceText.precise(
        value ?? 0,
        color: col,
        fontWeight: FontWeight.w800,
        strikethrough: valueStrike,
        style: bold ? theme.textTheme.titleMedium : theme.textTheme.bodySmall,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  (bold
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(
                        color: bold ? AppColors.black : AppColors.muted,
                        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      ),
            ),
          ),
          val,
        ],
      ),
    );
  }
}

class _ReassuranceCard extends StatelessWidget {
  const _ReassuranceCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: ShapeDecoration(
              color: AppColors.brandSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const AppIcon(
              AppIcons.verifiedUserOutlined,
              color: AppColors.brandStrong,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safe and secure',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cancel any time before the shop confirms.',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSizes.productImageSize,
              height: AppSizes.productImageSize,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusLg),
              ),
              alignment: Alignment.center,
              child: const AppIcon(
                AppIcons.shoppingCartOutlined,
                size: AppSizes.iconHuge,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              'Your cart is empty',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Browse the marketplace and add items to start checkout.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.lg),
            AppButton.primary(
              label: 'Continue shopping',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Footer ─────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.total,
    required this.savings,
    required this.isPlacing,
    required this.onProceed,
  });
  final double total;
  final double savings;
  final bool isPlacing;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      color: AppColors.white,
      elevation: 12,
      shadowColor: AppColors.black.withValues(alpha: 0.15),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSizes.md,
          AppSizes.sm,
          AppSizes.md,
          AppSizes.sm + bottomPad,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPriceText.precise(
                    total,
                    fontWeight: FontWeight.w800,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (savings > 0)
                    Wrap(
                      children: [
                        Text(
                          'You save ',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        AppPriceText.precise(
                          savings,
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    )
                  else
                    Text(
                      'Total payable',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Flexible(
              flex: 6,
              child: AppButton.primary(
                label: 'Proceed to checkout',
                onPressed: isPlacing ? null : onProceed,
                isLoading: isPlacing,
                trailingIcon: AppIcons.arrowForwardRounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
