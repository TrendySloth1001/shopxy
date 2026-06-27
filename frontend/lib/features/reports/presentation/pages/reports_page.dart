import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/reports/domain/entities/sales_report.dart';
import 'package:shopxy/features/reports/presentation/providers/reports_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReportsProvider>().load();
    });
  }

  Future<void> _pickRange(ReportsProvider p) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: p.from, end: p.to),
      locale: const Locale('en', 'IN'),
    );
    if (picked != null) {
      p.setRange(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ReportsProvider>();
    final dateFmt = DateFormat('d MMM yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: p.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.sm,
            ),
            child: InkWell(
              onTap: () => _pickRange(p),
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.md,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: AppSizes.iconMd),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        '${dateFmt.format(p.from)} → ${dateFmt.format(p.to)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded, size: AppSizes.iconMd),
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Row(
              children: [
                for (final k in ReportKind.values) ...[
                  _KindPill(
                    label: _labelFor(k),
                    selected: p.kind == k,
                    onTap: () => p.setKind(k),
                  ),
                  const SizedBox(width: AppSizes.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Expanded(
            child: p.isLoading
                ? const _ReportSkeleton()
                : p.error != null
                    ? _ErrorBlock(error: p.error!, onRetry: p.load)
                    : _ReportBody(provider: p),
          ),
        ],
      ),
    );
  }

  String _labelFor(ReportKind k) => switch (k) {
        ReportKind.sales => 'Sales',
        ReportKind.purchases => 'Purchases',
        ReportKind.gst => 'GST',
        ReportKind.pnl => 'P&L',
      };
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.inverseSurface : AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: BorderSide(color: selected ? AppColors.inverseSurface : AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.onInverse : AppColors.black,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: AppSizes.iconXl),
          const SizedBox(height: AppSizes.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.xxl),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.provider});
  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (provider.kind) {
      case ReportKind.sales:
        if (provider.sales == null) return const _LoadingHint();
        return _SalesView(report: provider.sales!);
      case ReportKind.purchases:
        if (provider.purchases == null) return const _LoadingHint();
        return _PurchasesView(report: provider.purchases!);
      case ReportKind.gst:
        if (provider.gst == null) return const _LoadingHint();
        return _GstView(report: provider.gst!);
      case ReportKind.pnl:
        if (provider.pnl == null) return const _LoadingHint();
        return _PnlView(report: provider.pnl!);
    }
  }
}

class _LoadingHint extends StatelessWidget {
  const _LoadingHint();
  @override
  Widget build(BuildContext context) => const _ReportSkeleton();
}

// ─────────────────────────────────────────────────────────────────────
// Skeleton widgets
// ─────────────────────────────────────────────────────────────────────

/// Full-page skeleton that mirrors the report layout while data loads.
class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: const [
        _BigStatSkeleton(),
        SizedBox(height: AppSizes.xl),
        _MiniBarSkeleton(),
        _SkeletonDivider(),
        _EyebrowSkeleton(),
        _LeaderRowSkeleton(),
        _LeaderRowSkeleton(),
        _LeaderRowSkeleton(),
        _SkeletonDivider(),
        _EyebrowSkeleton(),
        _LeaderRowSkeleton(),
        _LeaderRowSkeleton(),
        _LeaderRowSkeleton(),
      ],
    );
  }
}

/// Skeleton for _BigStat: small label line + large value block.
class _BigStatSkeleton extends StatelessWidget {
  const _BigStatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AppShimmerLine(widthFactor: 0.32, height: 10),
          SizedBox(height: AppSizes.sm),
          AppShimmerBox(width: 200, height: 44, radius: AppSizes.radiusSm),
          SizedBox(height: AppSizes.xs),
          AppShimmerLine(widthFactor: 0.55, height: 10),
        ],
      ),
    );
  }
}

/// Skeleton for the _MiniBar area.
class _MiniBarSkeleton extends StatelessWidget {
  const _MiniBarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppShimmerBox(
        width: double.infinity,
        height: 110,
        radius: AppSizes.radiusMd,
      ),
    );
  }
}

/// Skeleton for an _Eyebrow label.
class _EyebrowSkeleton extends StatelessWidget {
  const _EyebrowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.xl, AppSizes.lg, AppSizes.sm),
      child: AppShimmerLine(widthFactor: 0.28, height: 9),
    );
  }
}

/// Skeleton for a _LeaderRow: title+amount line, subtitle line, progress bar.
class _LeaderRowSkeleton extends StatelessWidget {
  const _LeaderRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: AppShimmerLine(widthFactor: 0.55, height: 13)),
              SizedBox(width: AppSizes.md),
              AppShimmerBox(width: 64, height: 13, radius: AppSizes.radiusXs),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          const AppShimmerLine(widthFactor: 0.38, height: 10),
          const SizedBox(height: AppSizes.sm),
          AppShimmerBox(
            width: double.infinity,
            height: AppSizes.xs,
            radius: AppSizes.radiusFull,
          ),
        ],
      ),
    );
  }
}

class _SkeletonDivider extends StatelessWidget {
  const _SkeletonDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.lg,
      ),
      child: Container(height: 1, color: AppColors.hairline),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Shared primitives
// ─────────────────────────────────────────────────────────────────────

NumberFormat _money() => NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 0,
    );

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.xl, AppSizes.lg, AppSizes.sm,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
        ),
      );
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value, this.helper});
  final String label;
  final String value;
  final String? helper;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                height: 1.05,
              ),
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(helper!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.lg,
        ),
        child: Container(height: 1, color: AppColors.hairline),
      );
}

class _MiniBar extends StatelessWidget {
  /// Tiny inline bar chart for daily series.
  const _MiniBar({required this.series});
  final List<DailyPoint> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        child: Text(
          'No activity in this range.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      );
    }
    final maxV = series.fold<double>(0, (m, p) => p.amount > m ? p.amount : m);
    return SizedBox(
      height: 110,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        child: LayoutBuilder(
          builder: (_, c) => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in series) ...[
                Expanded(
                  child: Tooltip(
                    message:
                        '${DateFormat('d MMM').format(p.day)}\n${_money().format(p.amount)}',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      height: maxV == 0
                          ? AppSizes.xs
                          : (p.amount / maxV).clamp(0.04, 1.0) * c.maxHeight,
                      decoration: ShapeDecoration(
                        color: AppColors.brand,
                        shape: AppShapes.squircle(AppSizes.radiusSm),
                      ),
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

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.max,
  });
  final String title;
  final String subtitle;
  final double amount;
  final double max;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = max == 0 ? 0.0 : (amount / max).clamp(0.02, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _money().format(amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          ClipPath(
            clipper: ShapeBorderClipper(
              shape: AppShapes.squircle(AppSizes.radiusFull),
            ),
            child: Container(
              height: AppSizes.xs,
              color: AppColors.hairline,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(color: AppColors.brand),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Views
// ─────────────────────────────────────────────────────────────────────

class _SalesView extends StatelessWidget {
  const _SalesView({required this.report});
  final SalesReport report;
  @override
  Widget build(BuildContext context) {
    final f = _money();
    final maxP = report.topProducts.fold<double>(
      0,
      (m, p) => p.amount > m ? p.amount : m,
    );
    final maxC = report.topCustomers.fold<double>(
      0,
      (m, c) => c.amount > m ? c.amount : m,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        _BigStat(
          label: 'TOTAL SALES',
          value: f.format(report.summary.total),
          helper:
              '${report.summary.invoiceCount} confirmed invoices · ${f.format(report.summary.taxAmount)} tax',
        ),
        const SizedBox(height: AppSizes.xl),
        _MiniBar(series: report.daily),
        const _Divider(),
        const _Eyebrow('TOP PRODUCTS'),
        for (final p in report.topProducts)
          _LeaderRow(
            title: p.productName,
            subtitle: '${p.productSku} · qty ${p.quantity.toStringAsFixed(0)}',
            amount: p.amount,
            max: maxP,
          ),
        const _Divider(),
        const _Eyebrow('TOP CUSTOMERS'),
        for (final c in report.topCustomers)
          _LeaderRow(
            title: c.name,
            subtitle: '${c.invoices} invoice${c.invoices == 1 ? "" : "s"}',
            amount: c.amount,
            max: maxC,
          ),
      ],
    );
  }
}

class _PurchasesView extends StatelessWidget {
  const _PurchasesView({required this.report});
  final PurchasesReport report;
  @override
  Widget build(BuildContext context) {
    final f = _money();
    final maxP = report.topProducts.fold<double>(0, (m, p) => p.amount > m ? p.amount : m);
    final maxV = report.topVendors.fold<double>(0, (m, c) => c.amount > m ? c.amount : m);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        _BigStat(
          label: 'TOTAL PURCHASES',
          value: f.format(report.summary.total),
          helper:
              '${report.summary.invoiceCount} confirmed bills · ${f.format(report.summary.taxAmount)} tax',
        ),
        const SizedBox(height: AppSizes.xl),
        _MiniBar(series: report.daily),
        const _Divider(),
        const _Eyebrow('TOP PURCHASED PRODUCTS'),
        for (final p in report.topProducts)
          _LeaderRow(
            title: p.productName,
            subtitle: '${p.productSku} · qty ${p.quantity.toStringAsFixed(0)}',
            amount: p.amount,
            max: maxP,
          ),
        const _Divider(),
        const _Eyebrow('TOP VENDORS'),
        for (final v in report.topVendors)
          _LeaderRow(
            title: v.name,
            subtitle: '${v.invoices} bill${v.invoices == 1 ? "" : "s"}',
            amount: v.amount,
            max: maxV,
          ),
      ],
    );
  }
}

class _GstView extends StatelessWidget {
  const _GstView({required this.report});
  final GstReport report;
  @override
  Widget build(BuildContext context) {
    final f = _money();
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'OUTPUT GST',
                  value: f.format(report.outputTax),
                  helper: 'Collected on sales',
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _StatBlock(
                  label: 'INPUT GST',
                  value: f.format(report.inputTax),
                  helper: 'Paid on purchases',
                  color: AppColors.accentIndigo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: _StatBlock(
            label: 'NET GST PAYABLE',
            value: f.format(report.netPayable),
            helper: report.netPayable >= 0
                ? 'You owe this to the tax authority'
                : 'You have an input credit',
            color: report.netPayable >= 0 ? AppColors.warning : AppColors.success,
            wide: true,
          ),
        ),
        const _Divider(),
        const _Eyebrow('OUTPUT GST BY RATE'),
        for (final r in report.outputByRate) _GstRow(rate: r),
        const _Divider(),
        const _Eyebrow('INPUT GST BY RATE'),
        for (final r in report.inputByRate) _GstRow(rate: r),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
    this.wide = false,
  });
  final String label;
  final String value;
  final String helper;
  final Color color;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.sm,
                height: AppSizes.sm,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            helper,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _GstRow extends StatelessWidget {
  const _GstRow({required this.rate});
  final GstRate rate;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: AppSizes.xs),
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusFull),
            ),
            child: Text(
              '${rate.rate.toStringAsFixed(rate.rate.truncateToDouble() == rate.rate ? 0 : 2)}%',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              'Taxable ${_money().format(rate.taxable)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          Text(
            _money().format(rate.tax),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PnlView extends StatelessWidget {
  const _PnlView({required this.report});
  final PnlReport report;
  @override
  Widget build(BuildContext context) {
    final f = _money();
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        _BigStat(
          label: 'NET PROFIT',
          value: f.format(report.netProfit),
          helper:
              'Gross margin ${(report.grossMargin * 100).toStringAsFixed(1)}%',
        ),
        const SizedBox(height: AppSizes.xl),
        const _Divider(),
        _PnlRow(label: 'Revenue', value: f.format(report.revenue), strong: true),
        _PnlRow(label: 'Cost of goods sold', value: '− ${f.format(report.cogs)}'),
        _PnlRow(
          label: 'Gross profit',
          value: f.format(report.grossProfit),
          strong: true,
        ),
        const _Divider(),
        _PnlRow(
          label: 'Adjustment write-offs',
          value: '− ${f.format(report.writeoffs)}',
        ),
        _PnlRow(
          label: 'Net profit',
          value: f.format(report.netProfit),
          strong: true,
          big: true,
        ),
      ],
    );
  }
}

class _PnlRow extends StatelessWidget {
  const _PnlRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.big = false,
  });
  final String label;
  final String value;
  final bool strong;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: (big ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
                  ?.copyWith(
                color: AppColors.black,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: (big ? theme.textTheme.titleLarge : theme.textTheme.bodyLarge)
                ?.copyWith(
              color: AppColors.black,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
