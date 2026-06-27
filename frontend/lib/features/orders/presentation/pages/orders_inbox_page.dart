import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/orders/domain/entities/merchant_order.dart';
import 'package:shopxy/features/orders/presentation/pages/merchant_order_detail_page.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

class OrdersInboxPage extends StatefulWidget {
  const OrdersInboxPage({super.key});

  @override
  State<OrdersInboxPage> createState() => _OrdersInboxPageState();
}

class _OrdersInboxPageState extends State<OrdersInboxPage> {
  static const _tabs = [
    (label: AppStrings.tabPending, status: 'PENDING'),
    (label: AppStrings.tabConfirmed, status: 'CONFIRMED'),
    (label: AppStrings.tabRejected, status: 'REJECTED'),
    (label: AppStrings.tabAll, status: null),
  ];

  int _index = 0;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

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
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    // Debounce — types like "sol" hit the backend once, not three
    // times. Cheap to debounce client-side; saves a chatty inbox.
    _searchDebounce = Timer(AppDurations.searchDebounce, () {
      if (!mounted) return;
      context.read<OrdersProvider>().setSearch(value.trim());
    });
  }

  Future<void> _pickDateRange() async {
    final p = context.read<OrdersProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: p.from != null && p.to != null
          ? DateTimeRange(start: p.from!, end: p.to!)
          : null,
    );
    if (picked == null || !mounted) return;
    p.setDateRange(
      DateTime(picked.start.year, picked.start.month, picked.start.day),
      DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
    );
  }

  void _clearDateRange() {
    context.read<OrdersProvider>().setDateRange(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<OrdersProvider>();
    final canView = context.select<AuthProvider, bool>(
        (a) => a.user?.canView('orders') ?? false);
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? null : const ShellMenuButton(),
        title: const Text(AppStrings.orders),
        actions: [AccessReloadButton(onReload: () => p.load())],
      ),
      body: !canView
          ? const NoAccessView(title: 'Orders hidden')
          : Column(
        children: [
          // ── Status pills ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSizes.sm),
                      child: _Pill(
                        label: _tabs[i].label,
                        // Tiny count badge on Pending so a busy merchant
                        // sees the pile growing without leaving the
                        // inbox.
                        badge: _tabs[i].status == 'PENDING' && p.pendingCount > 0
                            ? p.pendingCount
                            : null,
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
          ),
          // ── Search + date filter row ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              0,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: AppStrings.inboxSearchHint,
                      prefixIcon:
                          const Icon(Icons.search_rounded, size: AppSizes.iconMd),
                      suffixIcon: p.search.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: AppSizes.iconMd),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius:
                            AppShapes.squircleRadius(AppSizes.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                _DateFilterChip(
                  from: p.from,
                  to: p.to,
                  onTap: _pickDateRange,
                  onClear: _clearDateRange,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: p.load,
              child: p.isLoading && p.orders.isEmpty
                  ? const _OrdersInboxSkeleton()
                  : p.error != null && p.orders.isEmpty
                      ? _ErrorState(message: p.error!, onRetry: p.load)
                      : p.orders.isEmpty
                          ? _EmptyInbox(
                              isPending: _tabs[_index].status == 'PENDING',
                              hasFilters: p.search.isNotEmpty ||
                                  p.from != null ||
                                  p.to != null,
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
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
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppColors.inverseSurface : AppColors.surfaceTint,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.onInverse : AppColors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.inverseSurface : AppColors.warning,
                    borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
                  ),
                  child: Text(
                    '$badge',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected ? AppColors.onInverse : AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.from,
    required this.to,
    required this.onTap,
    required this.onClear,
  });
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTap;
  final VoidCallback onClear;

  static final _fmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = from != null && to != null;
    final label =
        active ? '${_fmt.format(from!)} – ${_fmt.format(to!)}' : 'Any date';
    return Material(
      color: active ? AppColors.inverseSurface : AppColors.surfaceTint,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_rounded,
                size: AppSizes.iconSm,
                color: active ? AppColors.onInverse : AppColors.black,
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.onInverse : AppColors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (active) ...[
                const SizedBox(width: AppSizes.sm),
                InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    Icons.close_rounded,
                    size: AppSizes.iconSm,
                    color: AppColors.onInverse,
                  ),
                ),
              ],
            ],
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
    final preview = _itemPreviewText(order);
    return Material(
      color: AppColors.surface,
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (preview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '${_date.format(order.createdAt.toLocal())} · ${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
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
                  Text(
                    '₹${order.estimatedTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSizes.xs),
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

  /// "3 PCS Solder Wire Roll · 2 PCS Tea Bag (+1 more)" — built from
  /// the backend's itemsPreview projection so we never miss a list-row
  /// render due to a follow-up fetch.
  static String? _itemPreviewText(MerchantOrder order) {
    if (order.itemPreview.isEmpty) return null;
    final parts = order.itemPreview.map((p) {
      final qty = p.quantity.truncateToDouble() == p.quantity
          ? p.quantity.toInt().toString()
          : p.quantity.toStringAsFixed(2);
      return '$qty ${p.unit} ${p.productName}';
    }).toList();
    final remainder = order.itemCount - parts.length;
    final body = parts.join(' · ');
    return remainder > 0 ? '$body (+$remainder more)' : body;
  }

  AppStatusTone _tone(MerchantOrder o) {
    if (o.isConfirmed) return AppStatusTone.success;
    if (o.isRejected) return AppStatusTone.error;
    if (o.isCancelled) return AppStatusTone.neutral;
    return AppStatusTone.warning;
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.isPending, required this.hasFilters});
  final bool isPending;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllCaughtUp = isPending && !hasFilters;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
            child: Icon(
              isAllCaughtUp
                  ? Icons.check_circle_outline_rounded
                  : hasFilters
                      ? Icons.search_off_rounded
                      : Icons.inbox_outlined,
              size: AppSizes.iconHuge,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Center(
          child: Text(
            isAllCaughtUp
                ? AppStrings.allCaughtUp
                : hasFilters
                    ? 'No matching orders'
                    : AppStrings.noOrdersYet,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
            child: Text(
              isAllCaughtUp
                  ? AppStrings.allCaughtUpHint
                  : hasFilters
                      ? 'Try a different search or date range.'
                      : 'New orders will appear here when customers place them.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Skeleton widgets ─────────────────────────────────────────────────────────

/// Full-list skeleton — 4 repeated [_OrderRowSkeleton] items separated by
/// [AppDivider]s, mirroring the real [ListView.separated] layout.
class _OrdersInboxSkeleton extends StatelessWidget {
  const _OrdersInboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, _) => const AppDivider(),
      itemBuilder: (_, _) => const _OrderRowSkeleton(),
    );
  }
}

/// Single-row skeleton that mirrors [_OrderRow]:
///   • Left column: title line (order ID + customer name), optional preview
///     line, metadata line
///   • Right column: price line + status-badge block
class _OrderRowSkeleton extends StatelessWidget {
  const _OrderRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row: order-id chip + customer name
                Row(
                  children: [
                    AppShimmerBox(
                      width: 48,
                      height: 14,
                      radius: AppSizes.radiusSm,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    const Expanded(
                      child: AppShimmerLine(widthFactor: 0.55, height: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Preview line (item names)
                const AppShimmerLine(widthFactor: 0.8, height: 12),
                const SizedBox(height: 6),
                // Metadata line (date · item count)
                const AppShimmerLine(widthFactor: 0.5, height: 11),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Right column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Price
              AppShimmerBox(
                width: 64,
                height: 14,
                radius: AppSizes.radiusSm,
              ),
              const SizedBox(height: AppSizes.xs),
              // Status badge
              AppShimmerBox(
                width: 72,
                height: 22,
                radius: AppSizes.radiusFull,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
        Icon(Icons.cloud_off_rounded,
            size: AppSizes.iconHuge, color: AppColors.muted),
        const SizedBox(height: AppSizes.md),
        Text(
          AppStrings.error,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
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
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(AppStrings.retry),
          ),
        ),
      ],
    );
  }
}
