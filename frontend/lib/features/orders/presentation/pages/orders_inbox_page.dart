import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/orders/domain/entities/merchant_order.dart';
import 'package:shopxy/features/orders/presentation/pages/merchant_order_detail_page.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

class OrdersInboxPage extends StatefulWidget {
  const OrdersInboxPage({super.key});

  @override
  State<OrdersInboxPage> createState() => _OrdersInboxPageState();
}

class _OrdersInboxPageState extends State<OrdersInboxPage> {
  static const _tabs = [
    (label: 'Pending', status: 'PENDING'),
    (label: 'Confirmed', status: 'CONFIRMED'),
    (label: 'All', status: null),
  ];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<OrdersProvider>();
      p.setStatusFilter(_tabs.first.status);
      p.refreshPendingCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Row(
              children: [
                for (int i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSizes.sm),
                    child: _Pill(
                      label: _tabs[i].label,
                      selected: i == _index,
                      onTap: () {
                        setState(() => _index = i);
                        p.setStatusFilter(_tabs[i].status);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: p.load,
              child: p.isLoading && p.orders.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : p.error != null && p.orders.isEmpty
                      ? Center(child: Text(p.error!))
                      : p.orders.isEmpty
                          ? const _EmptyInbox()
                          : ListView.separated(
                              itemCount: p.orders.length,
                              separatorBuilder: (_, _) => const AppDivider(),
                              itemBuilder: (_, i) =>
                                  _OrderRow(order: p.orders[i]),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.black : AppColors.surfaceTint,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.xs,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.white : AppColors.black,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final MerchantOrder order;

  static final _date = DateFormat('d MMM y · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MerchantOrderDetailPage(orderId: order.id),
          ),
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
                    Row(
                      children: [
                        Text(
                          '#${order.id}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            order.customerName,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                    '₹${order.estimatedTotal.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  AppStatusBadge(
                    label: order.status,
                    tone: _tone(order),
                    dense: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppStatusTone _tone(MerchantOrder o) {
    if (o.isConfirmed) return AppStatusTone.success;
    if (o.isRejected) return AppStatusTone.error;
    if (o.isCancelled) return AppStatusTone.neutral;
    return AppStatusTone.warning;
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();
  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        const Center(
          child: Text(
            'No orders here yet.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
