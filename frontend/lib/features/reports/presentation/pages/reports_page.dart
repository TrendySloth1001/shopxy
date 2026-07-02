import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/reports/domain/entities/sales_report.dart';
import 'package:shopxy/features/reports/presentation/providers/reports_provider.dart';
import 'package:shopxy/features/reports/presentation/widgets/calculator_view.dart';
import 'package:shopxy/features/reports/presentation/widgets/sold_products_table.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';

/// The reports workspace: four date-ranged reports (Sales, Purchases, GST, P&L)
/// plus a live Calculator tool — a faithful port of merchant-web's
/// `dashboard/reports` page.
enum _ReportTab { sales, purchases, gst, pnl, calculator }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  _ReportTab _tab = _ReportTab.sales;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReportsProvider>().load();
    });
  }

  void _selectTab(_ReportTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    final kind = switch (tab) {
      _ReportTab.sales => ReportKind.sales,
      _ReportTab.purchases => ReportKind.purchases,
      _ReportTab.gst => ReportKind.gst,
      _ReportTab.pnl => ReportKind.pnl,
      _ReportTab.calculator => null,
    };
    if (kind != null) context.read<ReportsProvider>().setKind(kind);
  }

  void _preset(ReportsProvider p, _Preset preset) {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final DateTime from = switch (preset) {
      _Preset.month => DateTime(now.year, now.month, 1),
      _Preset.days30 => DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 30)),
      // Indian financial year runs April → March.
      _Preset.fy => now.month >= 4
          ? DateTime(now.year, 4, 1)
          : DateTime(now.year - 1, 4, 1),
    };
    p.setRange(from, to);
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
    final l10n = AppLocalizations.of(context);
    final p = context.watch<ReportsProvider>();
    final dateFmt = DateFormat('d MMM yyyy');
    final isCalculator = _tab == _ReportTab.calculator;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reportsTitle),
        actions: [
          if (!isCalculator)
            IconButton(
              tooltip: l10n.reportsRefresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: p.refresh,
            ),
        ],
      ),
      body: Column(
        children: [
          // Tabs.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.sm),
            child: Row(
              children: [
                for (final t in _ReportTab.values) ...[
                  _TabPill(
                    label: _tabLabel(t),
                    selected: _tab == t,
                    onTap: () => _selectTab(t),
                  ),
                  const SizedBox(width: AppSizes.sm),
                ],
              ],
            ),
          ),
          // Date range + presets — hidden for the live calculator tool.
          if (!isCalculator)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg, AppSizes.xs, AppSizes.lg, AppSizes.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
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
                          const Icon(Icons.calendar_today_outlined,
                              size: AppSizes.iconMd),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              '${dateFmt.format(p.from)} → ${dateFmt.format(p.to)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.expand_more_rounded,
                              size: AppSizes.iconMd),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Wrap(
                    spacing: AppSizes.xs,
                    children: [
                      _PresetChip(label: l10n.reportsPresetThisMonth, onTap: () => _preset(p, _Preset.month)),
                      _PresetChip(label: l10n.reportsPresetLast30Days, onTap: () => _preset(p, _Preset.days30)),
                      _PresetChip(label: l10n.reportsPresetThisFy, onTap: () => _preset(p, _Preset.fy)),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSizes.xs),
          Expanded(
            child: isCalculator
                ? const CalculatorView()
                : p.isLoading
                    ? const _ReportSkeleton()
                    : p.error != null
                        ? _ErrorBlock(error: p.error!, onRetry: p.load)
                        : _ReportBody(provider: p),
          ),
        ],
      ),
    );
  }

  String _tabLabel(_ReportTab t) {
    final l10n = AppLocalizations.of(context);
    return switch (t) {
      _ReportTab.sales => l10n.reportsTabSales,
      _ReportTab.purchases => l10n.reportsTabPurchases,
      _ReportTab.gst => l10n.reportsTabGst,
      _ReportTab.pnl => l10n.reportsTabPnl,
      _ReportTab.calculator => l10n.reportsTabCalculator,
    };
  }
}

enum _Preset { month, days30, fy }

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: AppSizes.sm),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.selected, required this.onTap});
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
    final l10n = AppLocalizations.of(context);
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
          FilledButton(onPressed: onRetry, child: Text(l10n.reportsRetry)),
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
        if (provider.sales == null) return const _ReportSkeleton();
        return _SalesView(report: provider.sales!);
      case ReportKind.purchases:
        if (provider.purchases == null) return const _ReportSkeleton();
        return _PurchasesView(report: provider.purchases!);
      case ReportKind.gst:
        if (provider.gst == null) return const _ReportSkeleton();
        return _GstView(report: provider.gst!);
      case ReportKind.pnl:
        if (provider.pnl == null) return const _ReportSkeleton();
        return _PnlView(report: provider.pnl!, from: provider.from, to: provider.to);
    }
  }
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
  const _BigStat({required this.label, required this.value, this.helper, this.tone});
  final String label;
  final String value;
  final String? helper;
  final Color? tone;
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
                color: tone,
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
    final l10n = AppLocalizations.of(context);
    if (series.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        child: Text(
          l10n.reportsNoActivityInRange,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      );
    }
    final maxV = series.fold<double>(0, (m, p) => p.amount > m ? p.amount : m);
    final total = series.fold<double>(0, (s, p) => s + p.amount);
    final perDay = series.isEmpty ? 0 : total / series.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
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
        ),
        const SizedBox(height: AppSizes.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('d MMM').format(series.first.day),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.subtle)),
              Text(DateFormat('d MMM').format(series.last.day),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.subtle)),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Text(
            l10n.reportsPace(
                _money().format(perDay), _money().format(perDay * 30)),
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
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
    final l10n = AppLocalizations.of(context);
    final f = _money();
    final s = report.summary;
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
          label: l10n.reportsTotalSales,
          value: f.format(s.total),
          helper: l10n.reportsSalesHelper('${s.invoiceCount}',
              f.format(s.taxAmount), f.format(s.netRevenue)),
        ),
        const SizedBox(height: AppSizes.xl),
        _MiniBar(series: report.daily),
        const _Divider(),
        _Eyebrow(l10n.reportsTopProducts),
        if (report.topProducts.isEmpty)
          _EmptyHint(l10n.reportsNoSalesInRange)
        else
          for (final p in report.topProducts)
            _LeaderRow(
              title: p.productName,
              subtitle: l10n.reportsSoldCount(p.quantity.toStringAsFixed(0)) +
                  (p.productSku.isNotEmpty ? " · ${p.productSku}" : ""),
              amount: p.amount,
              max: maxP,
            ),
        const _Divider(),
        _Eyebrow(l10n.reportsTopCustomers),
        if (report.topCustomers.isEmpty)
          _EmptyHint(l10n.reportsNoCustomersInRange)
        else
          for (final c in report.topCustomers)
            _LeaderRow(
              title: c.name,
              subtitle: c.invoices == 1
                  ? l10n.reportsInvoiceCountOne('${c.invoices}')
                  : l10n.reportsInvoiceCountOther('${c.invoices}'),
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
    final l10n = AppLocalizations.of(context);
    final f = _money();
    final s = report.summary;
    final maxP = report.topProducts.fold<double>(0, (m, p) => p.amount > m ? p.amount : m);
    final maxV = report.topVendors.fold<double>(0, (m, c) => c.amount > m ? c.amount : m);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        _BigStat(
          label: l10n.reportsTotalPurchases,
          value: f.format(s.total),
          helper: l10n.reportsPurchasesHelper(
              '${s.invoiceCount}', f.format(s.taxAmount)),
        ),
        const SizedBox(height: AppSizes.xl),
        _MiniBar(series: report.daily),
        const _Divider(),
        _Eyebrow(l10n.reportsTopPurchasedProducts),
        if (report.topProducts.isEmpty)
          _EmptyHint(l10n.reportsNoPurchasesInRange)
        else
          for (final p in report.topProducts)
            _LeaderRow(
              title: p.productName,
              subtitle: l10n.reportsBoughtCount(p.quantity.toStringAsFixed(0)) +
                  (p.productSku.isNotEmpty ? " · ${p.productSku}" : ""),
              amount: p.amount,
              max: maxP,
            ),
        const _Divider(),
        _Eyebrow(l10n.reportsTopVendors),
        if (report.topVendors.isEmpty)
          _EmptyHint(l10n.reportsNoVendorsInRange)
        else
          for (final v in report.topVendors)
            _LeaderRow(
              title: v.name,
              subtitle: v.invoices == 1
                  ? l10n.reportsBillCountOne('${v.invoices}')
                  : l10n.reportsBillCountOther('${v.invoices}'),
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
    final l10n = AppLocalizations.of(context);
    final f = _money();
    final owes = report.netPayable >= 0;
    final head = report.byHead;
    final hasCess = report.outputCess != 0 || report.inputCess != 0;
    final hasGst = report.outputTax != 0 || report.inputTax != 0;
    final returnedGst = report.returns?.gst ?? 0;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        // Headline — three stats.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: l10n.reportsOutputGst,
                  value: f.format(report.outputTax),
                  helper: l10n.reportsCollectedOnSales,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _StatBlock(
                  label: l10n.reportsInputGstItc,
                  value: f.format(report.inputTax),
                  helper: l10n.reportsPaidOnPurchases,
                  color: AppColors.accentIndigo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: _StatBlock(
            label: l10n.reportsNetGstPayable,
            value: f.format(report.netPayable.abs()),
            helper: owes
                ? l10n.reportsGstOwedNote
                : l10n.reportsGstCreditCarriedNote,
            color: owes ? AppColors.warning : AppColors.success,
            wide: true,
          ),
        ),

        // Head-wise split (GSTR-3B).
        if (head != null && hasGst) ...[
          _Eyebrow(l10n.reportsNetPayableByTaxHead),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: _GstHeadTable(report: report, head: head),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.sm, AppSizes.lg, 0),
            child: Text(
              l10n.reportsTaxHeadNote,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.subtle),
            ),
          ),
        ],

        // By rate.
        _Eyebrow(l10n.reportsOutputGstByRate),
        _RateBreakdown(rows: report.outputByRate, empty: l10n.reportsNoOutputGstInRange),
        _Eyebrow(l10n.reportsInputGstByRate),
        _RateBreakdown(rows: report.inputByRate, empty: l10n.reportsNoInputGstInRange),

        // Cess — only when there is any.
        if (hasCess) ...[
          _Eyebrow(l10n.reportsCess),
          _PnlRow(label: l10n.reportsOutputCess, value: f.format(report.outputCess), strong: true),
          _PnlRow(label: l10n.reportsInputCess, value: '− ${f.format(report.inputCess)}'),
          _PnlRow(
            label: l10n.reportsNetCessPayable,
            value: f.format(report.netCessPayable),
            strong: true,
            big: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.sm, AppSizes.lg, 0),
            child: Text(
              l10n.reportsCessNote,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.subtle),
            ),
          ),
        ],

        // Returns note.
        if (returnedGst > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.lg, AppSizes.lg, 0),
            child: Text(
              l10n.reportsOutputGstReturnsNote(f.format(returnedGst)),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.subtle),
            ),
          ),
      ],
    );
  }
}

/// GSTR-3B head-wise split: IGST / CGST / SGST rows with output, input (ITC)
/// and net columns, plus a totals footer.
class _GstHeadTable extends StatelessWidget {
  const _GstHeadTable({required this.report, required this.head});
  final GstReport report;
  final GstByHead head;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ClipPath(
      clipper: ShapeBorderClipper(shape: AppShapes.squircle(AppSizes.radiusMd)),
      child: Container(
        decoration: ShapeDecoration(
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          children: [
            _headerRow(context),
            _row(context, 'IGST', l10n.reportsHeadInterState, head.output.igst, head.input.igst,
                head.netPayable.igst),
            _row(context, 'CGST', l10n.reportsHeadCentral, head.output.cgst, head.input.cgst,
                head.netPayable.cgst),
            _row(context, 'SGST', l10n.reportsHeadState, head.output.sgst, head.input.sgst,
                head.netPayable.sgst),
            _totalRow(context),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        );
    return Container(
      color: AppColors.heroPanel,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      child: Row(
        children: [
          Expanded(child: Text(l10n.reportsColHead, style: style)),
          SizedBox(width: 68, child: Text(l10n.reportsColOutput, style: style, textAlign: TextAlign.right)),
          SizedBox(width: 68, child: Text(l10n.reportsColItc, style: style, textAlign: TextAlign.right)),
          SizedBox(width: 68, child: Text(l10n.reportsColNet, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String sub, double o, double i, double n) {
    final theme = Theme.of(context);
    final f = _money();
    Widget amt(String v, {bool strong = false}) => SizedBox(
          width: 68,
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(text: label),
                  TextSpan(
                    text: '  $sub',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.subtle),
                  ),
                ],
              ),
            ),
          ),
          amt(f.format(o)),
          amt(f.format(i)),
          amt(f.format(n), strong: true),
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final f = _money();
    Widget amt(String v, {bool bold = false}) => SizedBox(
          width: 68,
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
    return Container(
      color: AppColors.heroPanel,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(l10n.reportsColTotal,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                )),
          ),
          amt(f.format(report.outputTax)),
          amt(f.format(report.inputTax)),
          amt(f.format(report.netPayable), bold: true),
        ],
      ),
    );
  }
}

/// GST-by-rate breakdown — a Rate · Taxable · GST table with a total row.
class _RateBreakdown extends StatelessWidget {
  const _RateBreakdown({required this.rows, required this.empty});
  final List<GstRate> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final f = _money();
    if (rows.isEmpty) return _EmptyHint(empty);
    final totalTaxable = rows.fold<double>(0, (s, g) => s + g.taxable);
    final totalTax = rows.fold<double>(0, (s, g) => s + g.tax);
    final headStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.muted,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: AppShapes.squircle(AppSizes.radiusMd)),
        child: Container(
          decoration: ShapeDecoration(
            shape: AppShapes.squircle(
              AppSizes.radiusMd,
              side: BorderSide(color: AppColors.hairline),
            ),
          ),
          child: Column(
            children: [
              Container(
                color: AppColors.heroPanel,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md, vertical: AppSizes.sm),
                child: Row(
                  children: [
                    SizedBox(width: 52, child: Text(l10n.reportsColRate, style: headStyle)),
                    Expanded(
                        child: Text(l10n.reportsColTaxable,
                            style: headStyle, textAlign: TextAlign.right)),
                    SizedBox(
                        width: 96,
                        child: Text('GST',
                            style: headStyle, textAlign: TextAlign.right)),
                  ],
                ),
              ),
              for (final g in rows)
                Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.hairline)),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md, vertical: AppSizes.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sm, vertical: 1),
                          decoration: ShapeDecoration(
                            color: AppColors.surfaceTint,
                            shape: AppShapes.squircle(AppSizes.radiusFull),
                          ),
                          child: Text(
                            '${g.rate.toStringAsFixed(g.rate.truncateToDouble() == g.rate ? 0 : 2)}%',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          f.format(g.taxable),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: Text(
                          f.format(g.tax),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                color: AppColors.heroPanel,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md, vertical: AppSizes.sm),
                child: Row(
                  children: [
                    SizedBox(width: 52, child: Text(l10n.reportsColTotal, style: headStyle)),
                    Expanded(
                      child: Text(
                        f.format(totalTaxable),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: Text(
                        f.format(totalTax),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
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
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
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

class _PnlView extends StatelessWidget {
  const _PnlView({required this.report, required this.from, required this.to});
  final PnlReport report;
  final DateTime from;
  final DateTime to;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = _money();
    final r = report;
    final grossSales = r.revenue + r.refunds;
    final grossCogs = r.cogs + r.returnedCogs;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        _BigStat(
          label: l10n.reportsNetProfit,
          value: f.format(r.netProfit),
          tone: r.netProfit >= 0 ? AppColors.success : AppColors.error,
          helper: l10n.reportsGrossMargin(
              (r.grossMargin * 100).toStringAsFixed(1)),
        ),
        const SizedBox(height: AppSizes.xl),
        const _Divider(),
        _PnlRow(label: l10n.reportsRevenue, value: f.format(r.revenue), strong: true),
        _PnlRow(label: l10n.reportsCostOfGoodsSold, value: '− ${f.format(r.cogs)}'),
        _PnlRow(label: l10n.reportsGrossProfit, value: f.format(r.grossProfit), strong: true),
        _PnlRow(label: l10n.reportsAdjustmentWriteoffs, value: '− ${f.format(r.writeoffs)}'),
        _PnlRow(label: l10n.reportsNetProfitRow, value: f.format(r.netProfit), strong: true, big: true),

        // Proof — every headline figure traced back to its documents.
        _Eyebrow(l10n.reportsHowThisIsCalculated),
        _StatementRow(
          label: l10n.reportsConfirmedSales,
          basis: l10n.reportsConfirmedSalesBasis,
          value: f.format(grossSales),
        ),
        _StatementRow(
          label: l10n.reportsLessSalesReturns,
          basis: l10n.reportsLessSalesReturnsBasis,
          value: '− ${f.format(r.refunds)}',
        ),
        _StatementRow(label: l10n.reportsRevenueA, value: f.format(r.revenue), kind: _RowKind.subtotal),
        _StatementRow(
          label: l10n.reportsGoodsSoldAtCost,
          basis: l10n.reportsGoodsSoldAtCostBasis,
          value: f.format(grossCogs),
        ),
        _StatementRow(
          label: l10n.reportsLessReturnedGoodsRestocked,
          basis: l10n.reportsLessReturnedGoodsRestockedBasis,
          value: '− ${f.format(r.returnedCogs)}',
        ),
        _StatementRow(
            label: l10n.reportsCostOfGoodsSoldB, value: f.format(r.cogs), kind: _RowKind.subtotal),
        _StatementRow(
            label: l10n.reportsGrossProfitAB,
            value: f.format(r.grossProfit),
            kind: _RowKind.subtotal),
        _StatementRow(
          label: l10n.reportsLessStockWriteoffs,
          basis: l10n.reportsLessStockWriteoffsBasis,
          value: '− ${f.format(r.writeoffs)}',
        ),
        _StatementRow(
            label: l10n.reportsNetProfitFormula,
            value: f.format(r.netProfit),
            kind: _RowKind.total),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
          child: Text(
            l10n.reportsPnlNote((r.grossMargin * 100).toStringAsFixed(1)),
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
          ),
        ),

        // Products sold in this range — one row per product; expand for its
        // full sale timeline.
        SoldProductsTable(from: from, to: to),
      ],
    );
  }
}

enum _RowKind { line, subtotal, total }

/// One row of the P&L "proof" statement (a contributing line with a muted
/// basis note, a ruled subtotal, or the final total).
class _StatementRow extends StatelessWidget {
  const _StatementRow({
    required this.label,
    required this.value,
    this.basis,
    this.kind = _RowKind.line,
  });
  final String label;
  final String value;
  final String? basis;
  final _RowKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = kind == _RowKind.subtotal;
    final total = kind == _RowKind.total;
    final ruled = subtotal || total;
    final labelStyle = total
        ? theme.textTheme.titleMedium
        : subtotal
            ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
            : theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted);
    final valueStyle = (total
            ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)
            : subtotal
                ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
                : theme.textTheme.bodyMedium)
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Container(
      decoration: ruled
          ? BoxDecoration(border: Border(top: BorderSide(color: AppColors.hairline)))
          : null,
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                if (basis != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      basis!,
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Text(value, style: valueStyle),
        ],
      ),
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.lg),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
        ),
      );
}
