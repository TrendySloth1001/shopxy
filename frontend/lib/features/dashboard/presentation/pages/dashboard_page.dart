import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';

/// Editorial-style dashboard. No boxed cards — every section flows
/// inline, separated by full-bleed hairlines and quiet section labels.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardProvider>().loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final stats = provider.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            onPressed: () => provider.loadStats(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: provider.isLoading && stats == null
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && stats == null
              ? AppErrorView(onRetry: () => provider.loadStats())
              : RefreshIndicator(
                  onRefresh: () => provider.loadStats(),
                  color: AppColors.brand,
                  backgroundColor: AppColors.white,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const _Greeting(),
                      const SizedBox(height: AppSizes.lg),
                      _ValueHeadline(stats: stats),
                      const SizedBox(height: AppSizes.xl),
                      _QuickStats(stats: stats),
                      const _SectionBreak(),
                      _StockPulse(stats: stats),
                      const _SectionBreak(),
                      if ((stats?.draftInvoiceCount ?? 0) > 0) ...[
                        _DraftsSection(stats: stats!),
                        const _SectionBreak(),
                      ],
                      _ActivitySection(stats: stats),
                      const SizedBox(height: AppSizes.huge),
                    ],
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Shared editorial primitives
// ─────────────────────────────────────────────────────────────────────

class _SectionBreak extends StatelessWidget {
  const _SectionBreak();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.xl,
      ),
      child: Container(height: 1, color: AppColors.hairline),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Greeting
// ─────────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting();

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('EEE, d MMM').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Here's how your shop is doing today.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            dateLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Big inventory value — flat headline (no card)
// ─────────────────────────────────────────────────────────────────────

class _ValueHeadline extends StatelessWidget {
  const _ValueHeadline({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 0,
    );
    final value = currencyFormat.format(stats?.totalStockValue ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              const _Eyebrow('INVENTORY VALUE'),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.4,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Estimated value of stock currently on hand.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 3-up quick stats — separated by vertical hairlines, no cards
// ─────────────────────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final productCount = stats?.totalProducts ?? 0;
    final activeCount = stats?.activeProducts ?? productCount;
    final categoryCount = stats?.totalCategories ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StatColumn(label: 'Products', value: '$productCount'),
            _ThinVRule(),
            _StatColumn(label: 'Active', value: '$activeCount'),
            _ThinVRule(),
            _StatColumn(label: 'Categories', value: '$categoryCount'),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinVRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      color: AppColors.hairline,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Stock pulse — inline thin segmented bar, no surrounding card
// ─────────────────────────────────────────────────────────────────────

class _StockPulse extends StatelessWidget {
  const _StockPulse({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stats?.totalProducts ?? 0;
    final low = stats?.lowStockCount ?? 0;
    final out = stats?.outOfStockCount ?? 0;
    final healthy = (total - low - out).clamp(0, total).toInt();
    final pct = total == 0 ? 0 : ((healthy / total) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Eyebrow('STOCK PULSE'),
              const Spacer(),
              Text(
                total == 0 ? '—' : '$pct% healthy',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.brandStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          _ThinStackedBar(
            healthy: healthy,
            low: low,
            out: out,
            total: total,
          ),
          const SizedBox(height: AppSizes.md),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall ?? const TextStyle(),
            child: Wrap(
              spacing: AppSizes.lg,
              runSpacing: AppSizes.sm,
              children: [
                _PulseLegend(
                  color: AppColors.brand,
                  label: 'In good stock',
                  value: '$healthy',
                ),
                _PulseLegend(
                  color: AppColors.warning,
                  label: AppStrings.lowStock,
                  value: '$low',
                ),
                _PulseLegend(
                  color: AppColors.error,
                  label: AppStrings.outOfStock,
                  value: '$out',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinStackedBar extends StatelessWidget {
  const _ThinStackedBar({
    required this.healthy,
    required this.low,
    required this.out,
    required this.total,
  });

  final int healthy;
  final int low;
  final int out;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Container(
        height: 6,
        decoration: ShapeDecoration(
          color: AppColors.hairline,
          shape: AppShapes.squircle(AppSizes.radiusFull),
        ),
      );
    }
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (healthy > 0)
              Expanded(
                flex: healthy,
                child: Container(color: AppColors.brand),
              ),
            if (low > 0)
              Expanded(
                flex: low,
                child: Container(color: AppColors.warning),
              ),
            if (out > 0)
              Expanded(flex: out, child: Container(color: AppColors.error)),
          ],
        ),
      ),
    );
  }
}

class _PulseLegend extends StatelessWidget {
  const _PulseLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSizes.sm),
        Text(
          '$value ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label.toLowerCase(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Drafts — flat list, no card
// ─────────────────────────────────────────────────────────────────────

class _DraftsSection extends StatelessWidget {
  const _DraftsSection({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = stats.draftInvoiceCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Eyebrow('PENDING DRAFTS'),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      '$count draft ${count == 1 ? "invoice" : "invoices"} '
                      'waiting to be confirmed.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Stock has not been deducted yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        for (final d in stats.recentDrafts) _DraftRow(draft: d),
      ],
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.draft});
  final DashboardDraftInvoice draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: draft.id),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Icon(
              draft.isSale
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 16,
              color: draft.isSale ? AppColors.success : AppColors.accentIndigo,
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.counterpartyName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${draft.invoiceNo} · '
                    '${draft.itemCount} ${draft.itemCount == 1 ? "item" : "items"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${AppStrings.currencySymbol}${draft.total.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSizes.xs),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Recent activity — flat list, no card
// ─────────────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = stats?.recentTransactions ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: const _Eyebrow('RECENT ACTIVITY'),
        ),
        const SizedBox(height: AppSizes.md),
        if (transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.xl,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timeline_rounded,
                  size: AppSizes.iconMd,
                  color: AppColors.subtle,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Text(
                    'No stock movements yet. Your recent in/out activity will appear here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final t in transactions) _TransactionRow(transaction: t),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});
  final StockTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = transaction.isStockIn;
    final isOut = transaction.isStockOut;

    final accent = isIn
        ? AppColors.success
        : isOut
            ? AppColors.error
            : AppColors.accentIndigo;
    final accentSoft = isIn
        ? AppColors.successSoft
        : isOut
            ? AppColors.errorSoft
            : AppColors.accentIndigoSoft;
    final icon = isIn
        ? Icons.south_west_rounded
        : isOut
            ? Icons.north_east_rounded
            : Icons.swap_horiz_rounded;
    final sign = isIn ? '+' : (isOut ? '-' : '');
    final qty = transaction.quantity;
    final qtyText = qty.truncateToDouble() == qty
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(2);
    final timeFormat = DateFormat('d MMM · hh:mm a');

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: ShapeDecoration(
              color: accentSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.productName ??
                      'Product #${transaction.productId}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  timeFormat.format(transaction.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$sign$qtyText',
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
