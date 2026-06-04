import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/order_detail_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/core/router/app_shell.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_price_text.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/widgets/empty_state.dart';

/// Order status buckets used by the filter chips. Each order is placed
/// in exactly one bucket via [_statusOf] so it shows once per filter.
enum OrderFilter { all, pending, confirmed, cancelled, declined }

extension _OrderFilterX on OrderFilter {
  String get label => switch (this) {
        OrderFilter.all => 'All',
        OrderFilter.pending => 'Pending',
        OrderFilter.confirmed => 'Confirmed',
        OrderFilter.cancelled => 'Cancelled',
        OrderFilter.declined => 'Declined',
      };

  /// Empty-state copy when a filter has no orders.
  String get emptyLine => switch (this) {
        OrderFilter.all => "You haven't placed any orders yet",
        OrderFilter.pending => 'No orders waiting on a seller',
        OrderFilter.confirmed => 'No confirmed orders yet',
        OrderFilter.cancelled => 'No cancelled orders',
        OrderFilter.declined => 'No declined orders',
      };
}

/// Classifies a parent order into a single bucket. Priority reflects
/// "what needs my attention / is still alive": a still-pending slice
/// dominates, then any confirmed slice (order is going ahead), then the
/// dead states (declined / cancelled).
OrderFilter _statusOf(CustomerOrder o) {
  final c = o.shopOrders;
  if (c.isEmpty) return OrderFilter.pending;
  final pending = c.where((x) => x.isPending).length;
  final confirmed = c.where((x) => x.isConfirmed).length;
  final rejected = c.where((x) => x.isRejected).length;
  final cancelled = c.where((x) => x.isCancelled).length;
  if (pending > 0) return OrderFilter.pending;
  if (confirmed > 0) return OrderFilter.confirmed;
  if (rejected >= cancelled) return OrderFilter.declined;
  return OrderFilter.cancelled;
}

/// "My Orders" inbox — a filterable, card-per-order list. Chips across
/// the top scope the list to a status (All / Pending / Confirmed /
/// Cancelled / Declined) with live counts. Each card is scannable: order
/// id + aggregate status pill, seller attribution, item count + date,
/// and the grand total. We deliberately do NOT surface merchant
/// phone/email — only the public shop name.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  OrderFilter _filter = OrderFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Skip the /me/orders fetch for guests — the page renders a
      // sign-in prompt instead. main.dart's auth listener will trigger
      // load() automatically if the user signs in.
      if (context.read<AuthProvider>().isAuthenticated) {
        context.read<OrdersProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = context.select<AuthProvider, bool>((a) => a.isGuest);
    if (isGuest) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: const AppAppBar(title: AppStrings.myOrders),
        body: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Sign in to see your orders',
          subtitle:
              'Your purchases, tracking and invoices live here once you have an account.',
          action: AppButton.primary(
            label: 'Sign in',
            icon: Icons.login_rounded,
            onPressed: () => requireAuth(
              context,
              reason: 'View your orders, tracking and invoices in one place.',
            ),
          ),
        ),
      );
    }

    final p = context.watch<OrdersProvider>();
    final orders = p.orders;
    final hasOrders = orders.isNotEmpty;

    // Counts per bucket (single pass), for the chip badges.
    final counts = <OrderFilter, int>{OrderFilter.all: orders.length};
    for (final o in orders) {
      final s = _statusOf(o);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final visible = _filter == OrderFilter.all
        ? orders
        : orders.where((o) => _statusOf(o) == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppAppBar(
        title: AppStrings.myOrders,
        subtitle: hasOrders
            ? '${orders.length} ${orders.length == 1 ? 'order' : 'orders'}'
            : null,
      ),
      body: Column(
        children: [
          if (hasOrders)
            _FilterBar(
              selected: _filter,
              counts: counts,
              onSelect: (f) => setState(() => _filter = f),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: p.load,
              color: AppColors.brand,
              child: p.isLoading && orders.isEmpty
                  ? const _LoadingState()
                  : p.error != null && orders.isEmpty
                      ? _ErrorState(message: p.error!, onRetry: p.load)
                      : orders.isEmpty
                          ? const _EmptyOrders()
                          : visible.isEmpty
                              ? _FilteredEmpty(filter: _filter)
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSizes.lg,
                                    AppSizes.sm,
                                    AppSizes.lg,
                                    AppSizes.lg,
                                  ),
                                  itemCount: visible.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: AppSizes.md),
                                  itemBuilder: (_, i) =>
                                      _OrderCard(order: visible[i]),
                                ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelect,
  });
  final OrderFilter selected;
  final Map<OrderFilter, int> counts;
  final ValueChanged<OrderFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    // All is always shown; status chips appear only when they have
    // orders (or are currently selected) so the bar stays uncluttered.
    final chips = <OrderFilter>[
      OrderFilter.all,
      for (final f in [
        OrderFilter.pending,
        OrderFilter.confirmed,
        OrderFilter.cancelled,
        OrderFilter.declined,
      ])
        if ((counts[f] ?? 0) > 0 || selected == f) f,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: SizedBox(
        height: AppSizes.huge,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg, vertical: AppSizes.sm),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
          itemBuilder: (_, i) {
            final f = chips[i];
            return _FilterChip(
              label: f.label,
              count: counts[f] ?? 0,
              selected: selected == f,
              onTap: () => onSelect(f),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.black;
    return Material(
      color: selected ? AppColors.black : AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.hairline, width: 1),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: AppSizes.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? AppColors.white.withValues(alpha: 0.7)
                          : AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── List row card ───────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final CustomerOrder order;

  static final _date = DateFormat('d MMM, h:mm a');

  @override
  Widget build(BuildContext context) {
    final (color, soft, icon) = _aggregateVisual(order);
    final itemCount = order.totalItemCount;

    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline, width: 1),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailPage(orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: order id + aggregate status pill
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.id}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.black,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  _StatusPill(
                    label: order.aggregateStatusLabel,
                    color: color,
                    soft: soft,
                    icon: icon,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                _sellerLine(order),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${itemCount == 1 ? "1 item" : "$itemCount items"} · '
                '${_date.format(order.createdAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSizes.sm),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: AppSizes.sm),
              // Bottom: grand total + a "to pay" nudge + chevron
              Row(
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  AppPriceText.precise(
                    order.estimatedTotal,
                    fontWeight: FontWeight.w800,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const Spacer(),
                  if (order.needsOnlinePayment)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm, vertical: 3),
                      decoration: ShapeDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        shape: AppShapes.squircle(AppSizes.radiusFull),
                      ),
                      child: const Text(
                        'PAYMENT DUE',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.subtle,
                      size: AppSizes.iconMd,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Sold by Foo", "Sold by Foo & Bar", "Sold by Foo & 2 others".
  static String _sellerLine(CustomerOrder order) {
    final names =
        order.shopOrders.map((s) => s.shop?.displayName ?? 'Seller').toList();
    if (names.isEmpty) return 'No sellers';
    if (names.length == 1) return 'Sold by ${names[0]}';
    if (names.length == 2) return 'Sold by ${names[0]} & ${names[1]}';
    return 'Sold by ${names[0]} & ${names.length - 1} others';
  }

  /// Aggregate visual across the parent's children. Mirrors the order
  /// detail hero so the list row and detail header agree at a glance.
  static (Color, Color, IconData) _aggregateVisual(CustomerOrder o) {
    final children = o.shopOrders;
    if (children.isEmpty) {
      return (AppColors.muted, AppColors.surfaceTint,
          Icons.help_outline_rounded);
    }
    final confirmed = children.where((c) => c.isConfirmed).length;
    final pending = children.where((c) => c.isPending).length;
    final rejected = children.where((c) => c.isRejected).length;
    final cancelled = children.where((c) => c.isCancelled).length;
    final total = children.length;
    if (confirmed == total) {
      return (AppColors.success, AppColors.successSoft,
          Icons.check_circle_rounded);
    }
    if (cancelled == total) {
      return (AppColors.muted, AppColors.surfaceTint,
          Icons.do_disturb_alt_rounded);
    }
    if (rejected == total) {
      return (AppColors.error, AppColors.errorSoft, Icons.cancel_rounded);
    }
    if (pending == total) {
      return (AppColors.warning, AppColors.warningSoft, Icons.schedule_rounded);
    }
    return (AppColors.warning, AppColors.warningSoft,
        Icons.hourglass_bottom_rounded);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.soft,
    required this.icon,
  });
  final String label;
  final Color color;
  final Color soft;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 3),
      decoration: ShapeDecoration(
        color: soft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: AppSizes.xs),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── States ──────────────────────────────────────────────────────────

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.filter});
  final OrderFilter filter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppSizes.massive),
        const Icon(Icons.filter_list_off_rounded,
            size: AppSizes.iconHuge, color: AppColors.subtle),
        const SizedBox(height: AppSizes.md),
        Text(
          filter.emptyLine,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.lg,
      ),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                AppShimmerBox(width: 80, height: 18, radius: AppSizes.radiusFull),
                Spacer(),
                AppShimmerBox(width: 70, height: 18, radius: AppSizes.radiusFull),
              ],
            ),
            SizedBox(height: AppSizes.md),
            Row(
              children: [
                AppShimmerBox(
                    width: AppSizes.productThumbSize,
                    height: AppSizes.productThumbSize,
                    radius: AppSizes.radiusSm),
                SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmerLine(widthFactor: 0.8, height: 12),
                      SizedBox(height: AppSizes.sm),
                      AppShimmerLine(widthFactor: 0.5, height: 10),
                      SizedBox(height: AppSizes.sm),
                      AppShimmerLine(widthFactor: 0.3, height: 10),
                    ],
                  ),
                ),
                AppShimmerBox(width: 60, height: 16, radius: AppSizes.radiusSm),
              ],
            ),
          ],
        ),
      ),
    );
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
            width: AppSizes.productImageSize,
            height: AppSizes.productImageSize,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusLg),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              size: AppSizes.iconHuge,
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
                ?.select(CustomerShellTab.home.index),
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
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppSizes.massive),
        const Icon(Icons.cloud_off_rounded,
            size: AppSizes.iconHuge, color: AppColors.muted),
        const SizedBox(height: AppSizes.md),
        Text(
          AppStrings.somethingWentWrong,
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.xs),
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
