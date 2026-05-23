import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/core/router/app_shell.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

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
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: AppStrings.myOrders),
      body: RefreshIndicator(
        onRefresh: p.load,
        color: AppColors.brand,
        child: p.isLoading && p.orders.isEmpty
            ? const _LoadingState()
            : p.error != null && p.orders.isEmpty
                ? _ErrorState(message: p.error!, onRetry: p.load)
                : p.orders.isEmpty
                    ? const _EmptyOrders()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: p.orders.length,
                        separatorBuilder: (_, index) => const Divider(
                          height: 1,
                          color: AppColors.hairline,
                        ),
                        itemBuilder: (_, i) => _OrderRow(order: p.orders[i]),
                      ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      itemCount: 5,
      separatorBuilder: (_, index) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, index) => Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          children: const [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerLine(widthFactor: 0.5, height: 14),
                  SizedBox(height: 8),
                  AppShimmerLine(widthFactor: 0.8, height: 10),
                  SizedBox(height: 6),
                  AppShimmerLine(widthFactor: 0.4, height: 10),
                ],
              ),
            ),
            AppShimmerBox(width: 64, height: 16, radius: 6),
          ],
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
    final previewText = _itemPreview(order);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Order #${order.id}',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (order.shop != null) ...[
                        const SizedBox(width: AppSizes.sm),
                        Flexible(
                          child: Text(
                            '· ${order.shop!.displayName}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (previewText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        previewText,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Text(
                    '${_date.format(order.createdAt)} · ${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppPriceText.precise(
                  order.estimatedTotal,
                  style: theme.textTheme.titleSmall,
                  fontWeight: FontWeight.w800,
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

  /// "Solder Wire Roll · Tea Bag (+3 more)" — preview from the
  /// itemsPreview backend payload, falling back gracefully when empty.
  static String? _itemPreview(CustomerOrder order) {
    if (order.itemPreview.isEmpty) return null;
    final names = order.itemPreview.map((i) => i.productName).toList();
    final remainder = order.itemCount - names.length;
    final preview = names.join(' · ');
    return remainder > 0 ? '$preview (+$remainder more)' : preview;
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
      padding: const EdgeInsets.all(AppSizes.xl),
      children: [
        const SizedBox(height: AppSizes.xxl),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusLg),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Text(
          AppStrings.emptyOrders,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          AppStrings.emptyOrdersHint,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.xl),
        Center(
          child: AppButton.primary(
            label: 'Browse products',
            icon: Icons.grid_view_rounded,
            onPressed: () => CustomerShellScope.of(context)
                ?.select(CustomerShellTab.browse.index),
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
    return ListView(
      // ListView lets RefreshIndicator still pull-to-refresh from the
      // error state — handy when the user lost connection briefly.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppSizes.massive),
        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.muted),
        const SizedBox(height: AppSizes.md),
        Text(
          AppStrings.somethingWentWrong,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Center(
          child: AppButton.secondary(
            label: AppStrings.tryAgain,
            icon: Icons.refresh_rounded,
            onPressed: () => onRetry(),
          ),
        ),
      ],
    );
  }
}
