import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/payments/razorpay_checkout.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Indian-grouped rupee formatter — "₹3,84,580.00". Shared by this
/// page and the home top-bar badge so the two read identically.
final _rupee =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

String formatPendingAmount(double v) => _rupee.format(v);

/// Flat list of every order awaiting an online payment. Deliberately
/// chrome-free — a total-due header and one divider-separated row per
/// order, each with a Pay now button that opens the Razorpay sheet
/// directly (no hop through the order detail page). Watches
/// [OrdersProvider] so a paid order drops off the list live.
class PendingPaymentsPage extends StatefulWidget {
  const PendingPaymentsPage({super.key});

  @override
  State<PendingPaymentsPage> createState() => _PendingPaymentsPageState();
}

class _PendingPaymentsPageState extends State<PendingPaymentsPage> {
  /// Id of the order whose payment sheet is currently open, so only that
  /// row's button shows a spinner.
  int? _payingId;

  /// Open the Razorpay sheet for [order]'s payable remainder, then
  /// refresh orders so a successful payment flips the list. Mirrors the
  /// order-detail Pay Now flow.
  Future<void> _pay(CustomerOrder order) async {
    if (_payingId != null) return;
    setState(() => _payingId = order.id);
    try {
      final cart = context.read<CartProvider>();
      final checkout = await cart.payForOrder(order.id);
      final result = await RazorpayCheckout().open(
        clientParams: checkout.clientParams,
        description: 'Order #${order.id}',
      );
      if (result.isSuccess) {
        // Webhook can lag (and can't reach localhost) — confirm now so
        // the order flips to PAID immediately. Best-effort.
        try {
          await cart.syncOrderPayment(order.id);
        } catch (_) {
          /* non-fatal — the reload below still reflects server state */
        }
      }
      if (!mounted) return;
      if (result.isSuccess) {
        showAppSnackbar(context,
            message: 'Payment successful', tone: AppSnackbarTone.success);
      } else if (result.outcome == RazorpayOutcome.dismissed) {
        showAppSnackbar(context,
            message: 'Payment cancelled', tone: AppSnackbarTone.error);
      } else {
        showAppSnackbar(context,
            message: result.message ?? 'Payment failed',
            tone: AppSnackbarTone.error);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final alreadyPaid =
            msg.contains('ALREADY_PAID') || msg.contains('already paid');
        showAppSnackbar(
          context,
          message: alreadyPaid
              ? 'This order is already paid'
              : 'Could not start payment: ${msg.replaceFirst('Exception: ', '')}',
          tone: alreadyPaid ? AppSnackbarTone.info : AppSnackbarTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _payingId = null);
      // A paid order should disappear from the list — pull fresh orders.
      if (mounted) await context.read<OrdersProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = context
        .watch<OrdersProvider>()
        .orders
        .where((o) => o.needsOnlinePayment)
        .toList();
    final total =
        pending.fold<double>(0, (sum, o) => sum + o.payableRemainder);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppAppBar(
        title: 'Pending payments',
        subtitle: pending.isEmpty
            ? null
            : '${pending.length} ${pending.length == 1 ? 'order' : 'orders'} awaiting payment',
      ),
      body: pending.isEmpty
          ? const _AllSettled()
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSizes.huge),
              children: [
                _TotalDueHeader(total: total),
                const Divider(height: 1, color: AppColors.hairline),
                for (final o in pending) ...[
                  _PendingOrderRow(
                    order: o,
                    paying: _payingId == o.id,
                    onPay: () => _pay(o),
                  ),
                  const Divider(height: 1, color: AppColors.hairline),
                ],
              ],
            ),
    );
  }
}

/// Plain "Total due ₹X" header — no card, just type on the canvas.
class _TotalDueHeader extends StatelessWidget {
  const _TotalDueHeader({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL DUE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            formatPendingAmount(total),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
        ],
      ),
    );
  }
}

/// One order: identity + amount on the left, a Pay now button on the
/// right. Tapping the row (outside the button) opens the order detail.
class _PendingOrderRow extends StatelessWidget {
  const _PendingOrderRow({
    required this.order,
    required this.paying,
    required this.onPay,
  });

  final CustomerOrder order;
  final bool paying;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(orderId: order.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatPendingAmount(order.payableRemainder),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            AppButton.primary(
              label: 'Pay now',
              size: AppButtonSize.sm,
              isLoading: paying,
              onPressed: paying ? null : onPay,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when there's nothing left to pay — e.g. the customer paid the
/// last order off while this page was open.
class _AllSettled extends StatelessWidget {
  const _AllSettled();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_outlined,
                size: 56, color: AppColors.success),
            const SizedBox(height: AppSizes.md),
            Text(
              "You're all paid up",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'No orders are waiting on a payment right now.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
