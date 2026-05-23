import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await context.read<OrdersProvider>().loadDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = o;
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

  Future<void> _cancel() async {
    final ordersProvider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ordersProvider.cancel(widget.orderId);
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _Body(order: _order!, onCancel: _cancel),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order, required this.onCancel});
  final CustomerOrderDetail order;
  final VoidCallback onCancel;

  static final _date = DateFormat('d MMM y · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, soft) = _statusVisual(order);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      children: [
        if (order.isConfirmed)
          _Banner(
            color: AppColors.success,
            soft: AppColors.successSoft,
            icon: Icons.check_circle_outline_rounded,
            title: AppStrings.orderConfirmed,
            body: order.linkedInvoiceNo != null
                ? 'Invoice ${order.linkedInvoiceNo}'
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
            body: 'Waiting for the shop to confirm your order.',
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
                      child: Text(
                        'Order #${order.id}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                                '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} ${item.unit} × ${AppStrings.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
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
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
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
