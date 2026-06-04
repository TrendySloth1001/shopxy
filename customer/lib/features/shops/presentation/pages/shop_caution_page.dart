import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/features/shops/presentation/widgets/caution_info_sheet.dart';
import 'package:shopxy_customer/features/shops/presentation/widgets/post_caution_sheet.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';
import 'package:shopxy_customer/shared/widgets/app_list_section.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

/// The caution / security deposit a shop holds against the customer. Flat,
/// divider-based layout: a balance + breakdown header, the customer's own
/// requests, and the full deposit/refund/set-off/forfeit history. The customer
/// can also post a new deposit (a request the shop approves).
class ShopCautionPage extends StatefulWidget {
  const ShopCautionPage({super.key, required this.shop});
  final LinkedShop shop;

  @override
  State<ShopCautionPage> createState() => _ShopCautionPageState();
}

class _ShopCautionPageState extends State<ShopCautionPage> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<ShopsProvider>();
      p.loadCaution(widget.shop);
      p.loadCautionRequests(widget.shop);
    });
  }

  Future<void> _refresh() async {
    final p = context.read<ShopsProvider>();
    await p.loadCaution(widget.shop);
    await p.loadCautionRequests(widget.shop);
  }

  String _money(double v) =>
      '${AppStrings.currencySymbol}${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShopsProvider>();
    final loading = p.isLoadingCaution(widget.shop);
    final ledger = p.cautionFor(widget.shop);
    final err = p.cautionErrorFor(widget.shop);
    final requests = p.cautionRequestsFor(widget.shop) ?? const [];

    final entries = ledger?.entries ?? const <ShopCautionTxn>[];
    final balance = ledger?.balance ?? 0;

    double sumOf(String t) =>
        entries.where((e) => e.type == t).fold(0.0, (s, e) => s + e.amount);
    final stats = <(String, double)>[
      ('Deposited', sumOf('DEPOSIT')),
      ('Returned', sumOf('REFUND')),
      ('Set-off', sumOf('ADJUSTMENT')),
      ('Forfeited', sumOf('FORFEIT')),
    ].where((s) => s.$2 > 0).toList();

    final pending = requests.where((r) => r.isPending).toList();
    final settled = requests.where((r) => !r.isPending).take(8).toList();
    final reqRows = [...pending, ...settled];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.cautionTitle),
        actions: [
          IconButton(
            onPressed: () => showCautionInfoSheet(context),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About caution deposits',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _refresh,
        child: loading && ledger == null
            ? const _CautionSkeleton()
            : err != null && ledger == null
                ? _Error(err: err, onRetry: _refresh)
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSizes.xxl),
                    children: [
                      // ── Balance + breakdown header (flat) ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.savings_rounded,
                                    color: AppColors.brand,
                                    size: AppSizes.iconMd),
                                const SizedBox(width: AppSizes.sm),
                                Text(
                                  'HELD BY ${(widget.shop.shopName ?? widget.shop.name).toUpperCase()}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              _money(balance),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: AppColors.brandStrong,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                            ),
                            if (stats.isNotEmpty) ...[
                              const SizedBox(height: AppSizes.md),
                              Row(
                                children: [
                                  for (final s in stats)
                                    Expanded(
                                        child: _Stat(
                                            label: s.$1, value: _money(s.$2))),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const AppDivider.flush(),

                      // ── Post a deposit ──
                      Padding(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => openPostCaution(
                              context,
                              shop: widget.shop,
                              onSubmitted: _refresh,
                            ),
                            icon:
                                const Icon(Icons.add_rounded, size: AppSizes.iconMd),
                            label: const Text(AppStrings.cautionPostCta),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: AppColors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: AppSizes.lg),
                              shape: AppShapes.squircle(AppSizes.radiusMd),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                      const AppDivider.flush(),

                      // ── Requests ──
                      if (reqRows.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.lg),
                        AppListSection(
                          title: AppStrings.cautionRequestsLabel,
                          flushDividers: true,
                          children: [
                            for (final r in reqRows)
                              _RequestRow(
                                  req: r,
                                  shop: widget.shop,
                                  dateFmt: _dateFmt),
                          ],
                        ),
                        const AppDivider.flush(),
                      ],

                      // ── History ──
                      const SizedBox(height: AppSizes.lg),
                      if (entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.xxl, horizontal: AppSizes.lg),
                          child: Center(
                            child: Text(AppStrings.cautionEmpty,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.muted)),
                          ),
                        )
                      else
                        AppListSection(
                          title: 'History',
                          children: [
                            for (final e in entries)
                              _LedgerRow(
                                  txn: e,
                                  dateFmt: _dateFmt,
                                  currency: _currency),
                          ],
                        ),
                    ],
                  ),
      ),
    );
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

class _CautionSkeleton extends StatelessWidget {
  const _CautionSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.xxl),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Header: icon + label chip
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppShimmerBox(
                    width: AppSizes.iconMd,
                    height: AppSizes.iconMd,
                    radius: AppSizes.radiusSm,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  AppShimmerLine(widthFactor: 0.45, height: 12),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              // Large balance amount
              AppShimmerLine(widthFactor: 0.55, height: 36),
              const SizedBox(height: AppSizes.md),
              // Stats row (3 columns)
              Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppShimmerLine(widthFactor: 0.6, height: 10),
                          const SizedBox(height: AppSizes.xs),
                          AppShimmerLine(widthFactor: 0.8, height: 16),
                        ],
                      ),
                    ),
                    if (i < 2) const SizedBox(width: AppSizes.md),
                  ],
                ],
              ),
            ],
          ),
        ),
        const AppDivider.flush(),

        // Full-width button placeholder
        Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: AppShimmerBox(
            width: double.infinity,
            height: 52,
            radius: AppSizes.radiusMd,
          ),
        ),
        const AppDivider.flush(),

        // History section header
        const SizedBox(height: AppSizes.lg),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg, vertical: AppSizes.sm),
          child: AppShimmerLine(widthFactor: 0.25, height: 14),
        ),

        // 6 skeleton transaction rows
        for (int i = 0; i < 6; i++) const _CautionTxnRowSkeleton(),
      ],
    );
  }
}

class _CautionTxnRowSkeleton extends StatelessWidget {
  const _CautionTxnRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.md),
      child: Row(
        children: [
          // Icon placeholder (squircle avatar)
          AppShimmerBox(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          // Text lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.5, height: 14),
                const SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.72, height: 11),
              ],
            ),
          ),
          // Amount value
          AppShimmerLine(widthFactor: 0.18, height: 14),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        const SizedBox(height: AppSizes.xs),
        Text(value,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.txn,
    required this.dateFmt,
    required this.currency,
  });
  final ShopCautionTxn txn;
  final DateFormat dateFmt;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final increases = txn.increasesHeld;
    final (icon, label, color, soft) = switch (txn.type) {
      'DEPOSIT' => (
          Icons.south_west_rounded,
          'Deposit',
          AppColors.success,
          AppColors.successSoft
        ),
      'REFUND' => (
          Icons.north_east_rounded,
          'Refund',
          AppColors.error,
          AppColors.errorSoft
        ),
      'FORFEIT' => (
          Icons.gavel_rounded,
          'Forfeited',
          AppColors.error,
          AppColors.errorSoft
        ),
      _ => (
          Icons.call_merge_rounded,
          'Adjusted to invoice',
          AppColors.accentIndigo,
          AppColors.accentIndigoSoft
        ),
    };
    final subtitle = <String>[
      dateFmt.format(txn.createdAt.toLocal()),
      if (txn.isAdjustment && txn.invoiceNo != null) 'Inv ${txn.invoiceNo}',
      if (!txn.isAdjustment && !txn.isForfeit && txn.mode != null) txn.mode!,
      if (txn.receiptNo != null) txn.receiptNo!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.md),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            decoration: ShapeDecoration(
                color: soft, shape: AppShapes.squircle(AppSizes.radiusSm)),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          Text(
            '${increases ? '+' : '-'}${currency.format(txn.amount)}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: increases ? AppColors.success : AppColors.error,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow(
      {required this.req, required this.shop, required this.dateFmt});
  final ShopCautionRequest req;
  final LinkedShop shop;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, soft) = switch (req.status) {
      'PENDING' => ('Pending', AppColors.warning, AppColors.warningSoft),
      'APPROVED' => ('Approved', AppColors.success, AppColors.successSoft),
      'REJECTED' => ('Declined', AppColors.error, AppColors.errorSoft),
      _ => ('Cancelled', AppColors.muted, AppColors.hairline),
    };
    final subtitle = <String>[
      dateFmt.format(req.createdAt.toLocal()),
      if (req.mode != null) req.mode!,
      if (req.hasBasket) '${req.basketCount} item(s)',
      if (req.isRejected && req.reviewNote != null) req.reviewNote!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${AppStrings.currencySymbol}${req.amount.toStringAsFixed(req.amount == req.amount.roundToDouble() ? 0 : 2)}',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm, vertical: AppSizes.xs),
                      decoration: ShapeDecoration(
                          color: soft,
                          shape: AppShapes.squircle(AppSizes.radiusFull)),
                      child: Text(label,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: color, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          if (req.isPending)
            TextButton(
              onPressed: () => _cancel(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text('Cancel',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final prov = context.read<ShopsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await prov.cancelCautionRequest(shop, req.id);
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.cautionRequestCancelled)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.err, required this.onRetry});
  final String err;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: AppSizes.iconXl),
            const SizedBox(height: AppSizes.sm),
            Text(err, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.md),
            FilledButton(
                onPressed: onRetry, child: const Text(AppStrings.retry)),
          ],
        ),
      ),
    );
  }
}
