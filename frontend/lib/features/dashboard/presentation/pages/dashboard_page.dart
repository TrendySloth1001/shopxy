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
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';

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
                  color: AppColors.black,
                  backgroundColor: AppColors.white,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const _GreetingHeader(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.lg,
                        ),
                        child: _HeroSnapshot(stats: stats),
                      ),
                      const SizedBox(height: AppSizes.xl),
                      const AppSectionHeader(title: 'INVENTORY HEALTH'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.lg,
                        ),
                        child: _HealthBreakdown(stats: stats),
                      ),
                      const SizedBox(height: AppSizes.xl),
                      const AppSectionHeader(title: 'NEEDS ATTENTION'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.lg,
                        ),
                        child: _AttentionRow(stats: stats),
                      ),
                      if ((stats?.draftInvoiceCount ?? 0) > 0) ...[
                        const SizedBox(height: AppSizes.lg),
                        const AppSectionHeader(title: 'PENDING DRAFTS'),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                          ),
                          child: _DraftsCard(stats: stats!),
                        ),
                      ],
                      const SizedBox(height: AppSizes.lg),
                      const AppSectionHeader(title: 'RECENT ACTIVITY'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.lg,
                        ),
                        child: _RecentActivity(stats: stats),
                      ),
                      const SizedBox(height: AppSizes.xxxl),
                    ],
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Greeting header
// ─────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

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
                  'Here\'s how your shop is doing.',
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
// Hero snapshot — inverted black card with stock value
// ─────────────────────────────────────────────────────────────────────

class _HeroSnapshot extends StatelessWidget {
  const _HeroSnapshot({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 0,
    );
    final value = currencyFormat.format(stats?.totalStockValue ?? 0);
    final productCount = stats?.totalProducts ?? 0;
    final categoryCount = stats?.totalCategories ?? 0;
    final activeCount = stats?.activeProducts ?? productCount;

    return Container(
      decoration: ShapeDecoration(
        color: AppColors.black,
        shape: AppShapes.squircle(AppSizes.radiusXl),
      ),
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                'INVENTORY VALUE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Container(height: 1, color: AppColors.white.withValues(alpha: 0.18)),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              _HeroMetric(label: 'Products', value: '$productCount'),
              _HeroDivider(),
              _HeroMetric(label: 'Active', value: '$activeCount'),
              _HeroDivider(),
              _HeroMetric(label: 'Categories', value: '$categoryCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});
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
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.6),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      color: AppColors.white.withValues(alpha: 0.18),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Inventory health — stacked bar + legend
// ─────────────────────────────────────────────────────────────────────

class _HealthBreakdown extends StatelessWidget {
  const _HealthBreakdown({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final total = stats?.totalProducts ?? 0;
    final low = stats?.lowStockCount ?? 0;
    final out = stats?.outOfStockCount ?? 0;
    final healthy = (total - low - out).clamp(0, total);
    final pct = total == 0 ? 0 : ((healthy / total) * 100).round();

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                    children: [
                      TextSpan(text: '$pct'),
                      TextSpan(
                        text: '%',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: 'healthy',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '$total items',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          _StackedBar(healthy: healthy, low: low, out: out, total: total),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              _LegendDot(
                color: AppColors.black,
                label: 'Healthy',
                value: '$healthy',
              ),
              const SizedBox(width: AppSizes.lg),
              _LegendDot(
                color: AppColors.warning,
                label: AppStrings.lowStock,
                value: '$low',
              ),
              const SizedBox(width: AppSizes.lg),
              _LegendDot(
                color: AppColors.error,
                label: AppStrings.outOfStock,
                value: '$out',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  const _StackedBar({
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
        height: 10,
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
        height: 10,
        child: Row(
          children: [
            if (healthy > 0)
              Expanded(
                flex: healthy,
                child: Container(color: AppColors.black),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({
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
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSizes.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Needs attention — side-by-side callouts
// ─────────────────────────────────────────────────────────────────────

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final low = stats?.lowStockCount ?? 0;
    final out = stats?.outOfStockCount ?? 0;

    if (low == 0 && out == 0) {
      return _AttentionCard(
        icon: Icons.verified_rounded,
        accent: AppColors.success,
        value: 'All clear',
        label: 'Every product is in healthy stock.',
        wide: true,
      );
    }

    return Row(
      children: [
        Expanded(
          child: _AttentionCard(
            icon: Icons.warning_amber_rounded,
            accent: AppColors.warning,
            value: '$low',
            label: AppStrings.lowStock,
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: _AttentionCard(
            icon: Icons.error_outline_rounded,
            accent: AppColors.error,
            value: '$out',
            label: AppStrings.outOfStock,
          ),
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    this.wide = false,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: wide
          ? Row(
              children: [
                _AccentIcon(icon: icon, accent: accent),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AccentIcon(icon: icon, accent: accent),
                const SizedBox(height: AppSizes.lg),
                Text(
                  value,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
    );
  }
}

class _AccentIcon extends StatelessWidget {
  const _AccentIcon({required this.icon, required this.accent});
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusSm,
          side: BorderSide(color: accent, width: 1.2),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: accent, size: AppSizes.iconMd),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Recent activity
// ─────────────────────────────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = stats?.recentTransactions ?? const [];

    if (transactions.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.xxl,
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.swap_vert_rounded,
                color: AppColors.muted,
                size: AppSizes.iconLg,
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                'No stock movements yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < transactions.length; i++) ...[
            if (i > 0) const AppDivider.flush(),
            _TransactionTile(transaction: transactions[i]),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});
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
            : AppColors.black;
    final icon = isIn
        ? Icons.arrow_downward_rounded
        : isOut
            ? Icons.arrow_upward_rounded
            : Icons.swap_horiz_rounded;
    final sign = isIn ? '+' : (isOut ? '-' : '');
    final qty = transaction.quantity;
    final qtyText = qty.truncateToDouble() == qty
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(2);
    final timeFormat = DateFormat('d MMM · hh:mm a');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(
                AppSizes.radiusSm,
                side: BorderSide(color: accent, width: 1.2),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: AppSizes.iconMd),
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

class _DraftsCard extends StatelessWidget {
  const _DraftsCard({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: ShapeDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: AppShapes.squircle(10),
                  ),
                  child: Icon(
                    Icons.edit_document,
                    size: 18,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stats.draftInvoiceCount} draft '
                        '${stats.draftInvoiceCount == 1 ? "invoice" : "invoices"}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Stock has NOT been deducted yet — confirm to post.',
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
          for (int i = 0; i < stats.recentDrafts.length; i++) ...[
            const AppDivider.flush(),
            _DraftRow(draft: stats.recentDrafts[i]),
          ],
        ],
      ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.sm,
        ),
        child: Row(
          children: [
            Icon(
              draft.isSale ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 16,
              color: draft.isSale ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.counterpartyName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${draft.invoiceNo} · ${draft.itemCount} ${draft.itemCount == 1 ? "item" : "items"}',
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
