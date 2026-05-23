import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrdersProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myOrders)),
      body: RefreshIndicator(
        onRefresh: p.load,
        color: AppColors.brand,
        child: p.isLoading && p.orders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : p.error != null && p.orders.isEmpty
                ? Center(child: Text(p.error!))
                : p.orders.isEmpty
                    ? const _EmptyOrders()
                    : ListView.separated(
                        itemCount: p.orders.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.hairline),
                        itemBuilder: (_, i) => _OrderRow(order: p.orders[i]),
                      ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final CustomerOrder order;

  static final _date = DateFormat('d MMM y · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, soft) = _statusVisual(order);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: order.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_date.format(order.createdAt)} · ${order.itemCount} items',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${AppStrings.currencySymbol}${order.estimatedTotal.toStringAsFixed(0)}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          ],
        ),
      ),
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

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        const SizedBox(height: AppSizes.massive),
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusLg),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.receipt_long_outlined,
                size: 48, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Text(
          AppStrings.emptyOrders,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          AppStrings.emptyOrdersHint,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
