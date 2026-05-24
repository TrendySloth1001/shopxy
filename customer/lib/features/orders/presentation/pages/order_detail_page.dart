import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  CustomerOrderDetail? _order;
  bool _loading = true;
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await context.read<OrdersProvider>().loadDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = o;
          _loading = false;
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

  /// Confirm + cancel. Designed to be reachable from the sticky bottom
  /// CTA so the destructive path is one tap deep but still gated by an
  /// `AppConfirmDialog`.
  Future<void> _cancel() async {
    final ok = await AppConfirmDialog.show(
      context,
      title: AppStrings.cancelOrderTitle,
      message: AppStrings.cancelOrderBody,
      confirmLabel: AppStrings.confirmCancelOrder,
      cancelLabel: AppStrings.keepOrder,
      danger: true,
    );
    if (!ok || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context.read<OrdersProvider>().cancel(widget.orderId);
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'Order cancelled',
        tone: AppSnackbarTone.success,
      );
      await _load();
    } on CancelOrderException catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: e.message,
        tone: AppSnackbarTone.error,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        tone: AppSnackbarTone.error,
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppAppBar(title: 'Order #${widget.orderId}'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.brand,
                  child: _Body(order: order!),
                ),
      bottomNavigationBar: order != null && order.isPending
          ? _CancelBar(
              cancelling: _cancelling,
              onCancel: _cancel,
            )
          : null,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order});
  final CustomerOrderDetail order;
  static final _date = DateFormat('d MMM y · h:mm a');

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        _StatusHero(order: order),
        const SizedBox(height: AppSizes.md),
        _ShopAndDateCard(order: order, date: _date.format(order.createdAt)),
        if (order.customerAddress != null && order.customerAddress!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _DeliverySnapshotCard(order: order),
        ],
        const SizedBox(height: AppSizes.md),
        _ItemsCard(order: order),
        const SizedBox(height: AppSizes.md),
        _TotalsCard(order: order),
        if (order.note != null && order.note!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _NoteCard(note: order.note!),
        ],
      ],
    );
  }
}

// ─── Sections ────────────────────────────────────────────────────────

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.order});
  final CustomerOrderDetail order;
  @override
  Widget build(BuildContext context) {
    final (label, color, soft, icon, message) = _visuals(order);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.md, AppSizes.lg, 0,
      ),
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: soft,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(color: color, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (String, Color, Color, IconData, String) _visuals(
      CustomerOrderDetail o) {
    if (o.isConfirmed) {
      return (
        AppStrings.orderConfirmed,
        AppColors.success,
        AppColors.successSoft,
        Icons.check_circle_outline_rounded,
        o.shop != null
            ? '${o.shop!.displayName} is preparing your order.'
            : 'The shop is preparing your order.',
      );
    }
    if (o.isRejected) {
      return (
        AppStrings.orderRejected,
        AppColors.error,
        AppColors.errorSoft,
        Icons.cancel_outlined,
        o.decisionNote ?? 'The shop declined this order.',
      );
    }
    if (o.isCancelled) {
      return (
        AppStrings.orderCancelled,
        AppColors.muted,
        AppColors.surfaceTint,
        Icons.do_disturb_alt_rounded,
        'This order was cancelled. No charges apply.',
      );
    }
    return (
      AppStrings.orderPending,
      AppColors.warning,
      AppColors.warningSoft,
      Icons.schedule_rounded,
      o.shop != null
          ? 'Waiting for ${o.shop!.displayName} to confirm.'
          : 'Waiting for the shop to confirm your order.',
    );
  }
}

class _ShopAndDateCard extends StatelessWidget {
  const _ShopAndDateCard({required this.order, required this.date});
  final CustomerOrderDetail order;
  final String date;
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
            width: 36, height: 36,
            decoration: ShapeDecoration(
              color: AppColors.brandSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.storefront_outlined,
                color: AppColors.brandStrong, size: 20),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.shop?.displayName ?? 'Order placed',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverySnapshotCard extends StatelessWidget {
  const _DeliverySnapshotCard({required this.order});
  final CustomerOrderDetail order;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: AppColors.brandStrong, size: 18),
              SizedBox(width: 6),
              Text(
                'Delivering to',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          if (order.customerName.isNotEmpty)
            Text(
              order.customerName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            order.customerAddress ?? '',
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    order.customerPhone!,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});
  final CustomerOrderDetail order;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm,
            ),
            child: Row(
              children: [
                Text(
                  '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < order.items.length; i++) ...[
            if (i != 0) const Divider(height: 1, color: AppColors.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.items[i].productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_qty(order.items[i].quantity)} ${order.items[i].unit} × ${AppStrings.currencySymbol}${order.items[i].unitPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.muted, fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  AppPriceText.precise(
                    order.items[i].total,
                    fontWeight: FontWeight.w800,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q.truncateToDouble() == q ? q.toInt().toString() : q.toStringAsFixed(2);
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.order});
  final CustomerOrderDetail order;
  @override
  Widget build(BuildContext context) {
    final invoice = order.linkedInvoice;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (invoice != null) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    AppStrings.finalTotal,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                AppPriceText.precise(
                  invoice.total,
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppStrings.estimatedTotal} (cart)',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
                AppPriceText.precise(
                  order.estimatedTotal,
                  color: AppColors.muted,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Invoice ${invoice.invoiceNo}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ] else ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    AppStrings.estimatedTotal,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                AppPriceText.precise(
                  order.estimatedTotal,
                  fontWeight: FontWeight.w800,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'The shop will confirm the final amount on their invoice.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final String note;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR NOTE',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelBar extends StatelessWidget {
  const _CancelBar({required this.cancelling, required this.onCancel});
  final bool cancelling;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: AppButton.danger(
          label: AppStrings.cancelOrder,
          icon: Icons.cancel_outlined,
          onPressed: cancelling ? null : onCancel,
          isLoading: cancelling,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.muted),
            const SizedBox(height: AppSizes.md),
            const Text(
              AppStrings.somethingWentWrong,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            AppButton.secondary(
              label: AppStrings.tryAgain,
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
