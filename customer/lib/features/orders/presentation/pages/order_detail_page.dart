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

  /// Confirms before cancelling — single-tap on red button was eating
  /// real orders.
  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.cancelOrderTitle),
        content: const Text(AppStrings.cancelOrderBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.keepOrder),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.confirmCancelOrder),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context.read<OrdersProvider>().cancel(widget.orderId);
      if (!mounted) return;
      await _load();
    } on CancelOrderException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.brand,
                  child: _Body(
                    order: _order!,
                    cancelling: _cancelling,
                    onCancel: _cancel,
                  ),
                ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.order,
    required this.cancelling,
    required this.onCancel,
  });
  final CustomerOrderDetail order;
  final bool cancelling;
  final VoidCallback onCancel;

  static final _date = DateFormat('d MMM y · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, soft) = _statusVisual(order);

    return ListView(
      // Always-scrollable so RefreshIndicator works even on tiny content.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      children: [
        if (order.isConfirmed)
          _Banner(
            color: AppColors.success,
            soft: AppColors.successSoft,
            icon: Icons.check_circle_outline_rounded,
            title: AppStrings.orderConfirmed,
            body: order.shop != null
                ? '${order.shop!.displayName} is preparing your order.'
                : 'The shop is preparing your order.',
          ),
        if (order.isRejected)
          _Banner(
            color: AppColors.error,
            soft: AppColors.errorSoft,
            icon: Icons.cancel_outlined,
            title: AppStrings.orderRejected,
            body: order.decisionNote ?? 'The shop declined this order.',
          ),
        if (order.isPending)
          _Banner(
            color: AppColors.warning,
            soft: AppColors.warningSoft,
            icon: Icons.schedule_rounded,
            title: AppStrings.orderPending,
            body: order.shop != null
                ? 'Waiting for ${order.shop!.displayName} to confirm.'
                : 'Waiting for the shop to confirm your order.',
          ),
        Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(
                AppSizes.radiusLg,
                side: const BorderSide(color: AppColors.hairline),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.id}',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (order.shop != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                order.shop!.displayName,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: ShapeDecoration(
                        color: soft,
                        shape: AppShapes.squircle(AppSizes.radiusFull),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _date.format(order.createdAt),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.md),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${_qty(item.quantity)} ${item.unit} × ${AppStrings.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${AppStrings.currencySymbol}${item.total.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                // For confirmed orders the merchant has computed real GST
                // / discount on the invoice. Show that authoritative
                // figure prominently — the cart estimate becomes a fine-
                // print line below.
                if (order.linkedInvoice != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.finalTotal,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${AppStrings.currencySymbol}${order.linkedInvoice!.total.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${AppStrings.estimatedTotal} (cart)',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                      Text(
                        '${AppStrings.currencySymbol}${order.estimatedTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invoice ${order.linkedInvoice!.invoiceNo}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.estimatedTotal,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                      Text(
                        '${AppStrings.currencySymbol}${order.estimatedTotal.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                if (order.note != null && order.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.md),
                  Text(
                    'Your note',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  Text(order.note!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        if (order.isPending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: OutlinedButton.icon(
              onPressed: cancelling ? null : onCancel,
              icon: cancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : const Icon(Icons.cancel_outlined, color: AppColors.error),
              label: const Text(
                AppStrings.cancelOrder,
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
      ],
    );
  }

  /// "5", "5.5", "5.25" — drops trailing zeros so units look sane.
  static String _qty(double q) =>
      q.truncateToDouble() == q ? q.toInt().toString() : q.toStringAsFixed(2);

  static (String, Color, Color) _statusVisual(CustomerOrder o) {
    if (o.isConfirmed) {
      return (AppStrings.orderConfirmed, AppColors.success, AppColors.successSoft);
    }
    if (o.isRejected) {
      return (AppStrings.orderRejected, AppColors.error, AppColors.errorSoft);
    }
    if (o.isCancelled) {
      return (AppStrings.orderCancelled, AppColors.muted, AppColors.surfaceTint);
    }
    return (AppStrings.orderPending, AppColors.warning, AppColors.warningSoft);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.muted),
            const SizedBox(height: AppSizes.md),
            Text(
              AppStrings.somethingWentWrong,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(AppStrings.tryAgain),
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.soft,
    required this.icon,
    required this.title,
    required this.body,
  });
  final Color color;
  final Color soft;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: ShapeDecoration(
          color: soft,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: BorderSide(color: color, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
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
