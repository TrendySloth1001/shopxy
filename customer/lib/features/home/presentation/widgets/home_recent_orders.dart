import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';

/// "Recent orders" — strip of up to 3 most-recent orders. Tap to open
/// the detail page. Renders nothing when the user has no orders yet
/// (the empty experience belongs on the Orders tab).
class HomeRecentOrders extends StatelessWidget {
  const HomeRecentOrders({super.key, required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    if (p.orders.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final recent = p.orders.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.xl,
            AppSizes.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent orders',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (p.orders.length > recent.length)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.black,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                    ),
                  ),
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Column(
            children: [
              for (int i = 0; i < recent.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSizes.sm),
                _OrderCard(order: recent[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = AppShapes.squircle(
      AppSizes.radiusMd,
      side: const BorderSide(color: AppColors.hairline),
    );
    final (statusLabel, statusFg, statusBg) = _statusStyle(order.status);

    return Material(
      color: AppColors.white,
      shape: shape,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailPage(orderId: order.id),
          ),
        ),
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: AppColors.surfaceTint,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.shop?.name ?? 'Order #${order.id}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.black,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AppPriceText.compact(order.estimatedTotal),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          decoration: ShapeDecoration(
                            color: statusBg,
                            shape: AppShapes.squircle(AppSizes.radiusFull),
                          ),
                          child: Text(
                            statusLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusFg,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            '${order.itemCount} ${order.itemCount == 1 ? "item" : "items"}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (String, Color, Color) _statusStyle(String status) {
    switch (status) {
      case 'PENDING':
        return ('Pending', AppColors.accentAmber, AppColors.accentAmberSoft);
      case 'CONFIRMED':
        return ('Confirmed', AppColors.success, AppColors.successSoft);
      case 'REJECTED':
        return ('Rejected', AppColors.error, AppColors.errorSoft);
      case 'CANCELLED':
        return ('Cancelled', AppColors.muted, AppColors.surfaceTint);
      default:
        return (status, AppColors.muted, AppColors.surfaceTint);
    }
  }
}
