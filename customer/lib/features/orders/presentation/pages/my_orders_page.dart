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

/// "My Orders" inbox — card-per-order layout so each row is visually
/// scannable: shop chip up top, item-name preview, item count + date,
/// status pill, and price on the right. We deliberately do NOT surface
/// merchant phone/email — only the public shop name — because customers
/// shouldn't be reaching out to merchants directly through the app.
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
              reason:
                  'View your orders, tracking and invoices in one place.',
            ),
          ),
        ),
      );
    }

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
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          AppSizes.md,
                          AppSizes.lg,
                          AppSizes.lg,
                        ),
                        itemCount: p.orders.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.md),
                        itemBuilder: (_, i) => _OrderCard(order: p.orders[i]),
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
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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
              const SizedBox(height: 4),
              // "Sold by X" / "Sold by X & 2 others" — Amazon-style
              // single-line attribution. Drops the verbose "N shops"
              // chip and the chip-strip; one sentence does both jobs.
              Text(
                _sellerLine(order),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${itemCount == 1 ? "1 item" : "$itemCount items"} · '
                '${_date.format(order.createdAt)}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: AppSizes.sm),
              // Bottom: grand total + chevron
              Row(
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
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
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.subtle,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Sold by Foo", "Sold by Foo & Bar", "Sold by Foo & 2 others" —
  /// the standard marketplace attribution line. Falls back gracefully
  /// when shop names are missing.
  static String _sellerLine(CustomerOrder order) {
    final names = order.shopOrders
        .map((s) => s.shop?.displayName ?? 'Seller')
        .toList();
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
      return (AppColors.warning, AppColors.warningSoft,
          Icons.schedule_rounded);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: soft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
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
                AppShimmerBox(width: 80, height: 18, radius: 999),
                Spacer(),
                AppShimmerBox(width: 70, height: 18, radius: 999),
              ],
            ),
            SizedBox(height: AppSizes.md),
            Row(
              children: [
                AppShimmerBox(width: 52, height: 52, radius: 8),
                SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmerLine(widthFactor: 0.8, height: 12),
                      SizedBox(height: 8),
                      AppShimmerLine(widthFactor: 0.5, height: 10),
                      SizedBox(height: 6),
                      AppShimmerLine(widthFactor: 0.3, height: 10),
                    ],
                  ),
                ),
                AppShimmerBox(width: 60, height: 16, radius: 6),
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
