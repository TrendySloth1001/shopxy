import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/domain/entities/kpi_breakdown.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:shopxy/features/reports/domain/entities/sales_report.dart';
import 'package:shopxy/features/reports/presentation/pages/reports_page.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendors_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// Which KPI card was tapped — mirrors the web `KpiDrawerKind`.
enum KpiDrillKind { sales, profit, receivables, payables }

/// Opens the KPI drill-down as a draggable bottom sheet — the mobile
/// equivalent of merchant-web's right-side `KpiDrawer` slide-over. Each kind
/// shows the breakdown behind that exact headline number (see the web
/// `components/kpi-drawers.tsx`).
Future<void> showKpiDrillSheet(
  BuildContext context, {
  required KpiDrillKind kind,
  required DashboardPeriod period,
}) {
  final apiClient = context.read<ApiClient>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _KpiDrillSheet(
      kind: kind,
      period: period,
      apiClient: apiClient,
      hostContext: context,
    ),
  );
}

/// The dashboard window mapped to an explicit date range for the range-scoped
/// bodies (sales / profit). Balances (receivables / payables) are not
/// range-scoped — they show the full outstanding position, matching web.
DateTimeRange _rangeFor(DashboardPeriod p) {
  final now = DateTime.now();
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final start = DateTime(now.year, now.month, now.day);
  final from = switch (p) {
    DashboardPeriod.today => start,
    DashboardPeriod.week => start.subtract(const Duration(days: 7)),
    DashboardPeriod.month => start.subtract(const Duration(days: 30)),
  };
  return DateTimeRange(start: from, end: to);
}

class _KpiDrillSheet extends StatelessWidget {
  const _KpiDrillSheet({
    required this.kind,
    required this.period,
    required this.apiClient,
    required this.hostContext,
  });

  final KpiDrillKind kind;
  final DashboardPeriod period;
  final ApiClient apiClient;
  final BuildContext hostContext;

  String _title(AppLocalizations l10n) => switch (kind) {
    KpiDrillKind.sales => l10n.dashboardSales,
    KpiDrillKind.profit => l10n.dashboardNetProfit,
    KpiDrillKind.receivables => l10n.dashboardReceivables,
    KpiDrillKind.payables => l10n.dashboardPayables,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusLg),
            ),
          ),
          child: Column(
            children: [
              const _Grabber(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  0,
                  AppSizes.sm,
                  AppSizes.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_title(l10n), style: DashText.titleMd),
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.closeRounded),
                      color: AppColors.muted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.hairline),
              Expanded(child: _body(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(ScrollController controller) {
    switch (kind) {
      case KpiDrillKind.sales:
        return _SalesBody(
          controller: controller,
          reports: ReportsRemoteDataSource(apiClient),
          range: _rangeFor(period),
          hostContext: hostContext,
        );
      case KpiDrillKind.profit:
        return _ProfitBody(
          controller: controller,
          reports: ReportsRemoteDataSource(apiClient),
          range: _rangeFor(period),
          hostContext: hostContext,
        );
      case KpiDrillKind.receivables:
        return _BreakdownBody(
          controller: controller,
          dashboard: DashboardRemoteDataSource(apiClient),
          isReceivables: true,
          hostContext: hostContext,
        );
      case KpiDrillKind.payables:
        return _BreakdownBody(
          controller: controller,
          dashboard: DashboardRemoteDataSource(apiClient),
          isReceivables: false,
          hostContext: hostContext,
        );
    }
  }
}

// ── Sales: products sold + a name/SKU filter ───────────────────────────

class _SalesBody extends StatefulWidget {
  const _SalesBody({
    required this.controller,
    required this.reports,
    required this.range,
    required this.hostContext,
  });

  final ScrollController controller;
  final ReportsRemoteDataSource reports;
  final DateTimeRange range;
  final BuildContext hostContext;

  @override
  State<_SalesBody> createState() => _SalesBodyState();
}

class _SalesBodyState extends State<_SalesBody> {
  final _searchController = TextEditingController();
  String _search = '';
  Future<SoldProductsPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _future = widget.reports.soldProducts(
      widget.range.start,
      widget.range.end,
      page: 1,
      limit: 50,
      search: _search,
    );
  }

  void _onSearchChanged(String value) {
    // Debounce: re-query 300ms after the last keystroke.
    final query = value.trim();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || query != _searchController.text.trim()) return;
      setState(() {
        _search = query;
        _load();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const AppIcon(
                AppIcons.searchRounded,
                size: AppSizes.iconMd,
              ),
              hintText: l10n.kpiDrawerSalesFilterHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide(color: AppColors.hairline),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<SoldProductsPage>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _Loading();
              }
              if (snap.hasError) {
                return _ErrorBlock(onRetry: () => setState(_load));
              }
              final page = snap.data;
              final rows = page?.data ?? const <SoldProduct>[];
              if (rows.isEmpty) {
                return _Empty(
                  _search.isEmpty
                      ? l10n.kpiDrawerNoSales
                      : l10n.kpiDrawerNoMatch,
                );
              }
              return ListView(
                controller: widget.controller,
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  0,
                  AppSizes.lg,
                  AppSizes.lg,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.kpiDrawerProductCount(
                            '${page!.pagination.total}',
                          ),
                          style: DashText.labelMd,
                        ),
                        Text(
                          l10n.kpiDrawerRevenue(
                            inr.format(page.totals.totalAmount),
                          ),
                          style: DashText.labelMd,
                        ),
                      ],
                    ),
                  ),
                  for (final p in rows) _SoldRow(product: p),
                  if (page.pagination.total > rows.length)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSizes.sm),
                      child: Text(
                        l10n.kpiDrawerShowingTop('${rows.length}'),
                        style: DashText.labelMd,
                      ),
                    ),
                  _MoreLink(
                    label: l10n.kpiDrawerViewFullReports,
                    onTap: () =>
                        _pushFull(widget.hostContext, const ReportsPage()),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SoldRow extends StatelessWidget {
  const _SoldRow({required this.product});
  final SoldProduct product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName ?? l10n.kpiDrawerUnnamedProduct,
                  style: DashText.bodyMd,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  l10n.kpiDrawerQtySold(
                        fmtQty(product.totalQuantity),
                        product.unit ?? l10n.kpiDrawerUnits,
                      ) +
                      (product.productSku != null &&
                              product.productSku!.isNotEmpty
                          ? ' · ${product.productSku}'
                          : ''),
                  style: DashText.bodySm,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            inr.format(product.totalAmount),
            style: DashText.bodyMd.copyWith(fontFeatures: tabularFigures),
          ),
        ],
      ),
    );
  }
}

// ── Net profit: the traced calculation ─────────────────────────────────

class _ProfitBody extends StatefulWidget {
  const _ProfitBody({
    required this.controller,
    required this.reports,
    required this.range,
    required this.hostContext,
  });

  final ScrollController controller;
  final ReportsRemoteDataSource reports;
  final DateTimeRange range;
  final BuildContext hostContext;

  @override
  State<_ProfitBody> createState() => _ProfitBodyState();
}

class _ProfitBodyState extends State<_ProfitBody> {
  Future<PnlReport>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = widget.reports.pnl(widget.range.start, widget.range.end);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<PnlReport>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        if (snap.hasError || !snap.hasData) {
          return _ErrorBlock(onRetry: () => setState(_load));
        }
        final pnl = snap.data!;
        return ListView(
          controller: widget.controller,
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            _TraceRow(label: l10n.reportsRevenue, value: pnl.revenue),
            _TraceRow(label: l10n.reportsLessSalesReturns, value: -pnl.refunds),
            _TraceRow(label: l10n.reportsCostOfGoodsSold, value: -pnl.cogs),
            const SizedBox(height: AppSizes.xs),
            _TraceRow(
              label: l10n.reportsGrossProfit,
              value: pnl.grossProfit,
              emphasise: true,
            ),
            _TraceRow(
              label: l10n.reportsAdjustmentWriteoffs,
              value: -pnl.writeoffs,
            ),
            Divider(height: AppSizes.xl, color: AppColors.hairline),
            _TraceRow(
              label: l10n.reportsNetProfitRow,
              value: pnl.netProfit,
              headline: true,
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xs),
              child: Text(
                l10n.reportsGrossMargin(pnl.grossMargin.toStringAsFixed(1)),
                style: DashText.labelMd,
              ),
            ),
            _MoreLink(
              label: l10n.kpiDrawerViewFullReports,
              onTap: () => _pushFull(widget.hostContext, const ReportsPage()),
            ),
          ],
        );
      },
    );
  }
}

class _TraceRow extends StatelessWidget {
  const _TraceRow({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.headline = false,
  });

  final String label;
  final double value;
  final bool emphasise;
  final bool headline;

  @override
  Widget build(BuildContext context) {
    final labelStyle = headline
        ? DashText.titleMd
        : emphasise
        ? DashText.bodyMd.semibold
        : DashText.bodyMd;
    final valueStyle = (headline ? DashText.headlineSm : labelStyle).copyWith(
      fontFeatures: tabularFigures,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: labelStyle)),
          const SizedBox(width: AppSizes.md),
          Text(inr.format(value), style: valueStyle),
        ],
      ),
    );
  }
}

// ── Receivables / Payables: debtors / creditors + their documents ──────

class _BreakdownBody extends StatefulWidget {
  const _BreakdownBody({
    required this.controller,
    required this.dashboard,
    required this.isReceivables,
    required this.hostContext,
  });

  final ScrollController controller;
  final DashboardRemoteDataSource dashboard;
  final bool isReceivables;
  final BuildContext hostContext;

  @override
  State<_BreakdownBody> createState() => _BreakdownBodyState();
}

class _BreakdownBodyState extends State<_BreakdownBody> {
  Future<KpiBreakdown>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = widget.isReceivables
      ? widget.dashboard.receivables()
      : widget.dashboard.payables();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<KpiBreakdown>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        if (snap.hasError || !snap.hasData) {
          return _ErrorBlock(onRetry: () => setState(_load));
        }
        final data = snap.data!;
        if (data.parties.isEmpty) {
          return _Empty(
            widget.isReceivables
                ? l10n.kpiDrawerNoReceivables
                : l10n.kpiDrawerNoPayables,
          );
        }
        return ListView(
          controller: widget.controller,
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.sm,
            AppSizes.lg,
            AppSizes.lg,
          ),
          children: [
            for (final party in data.parties)
              _CounterpartyTile(
                party: party,
                isReceivables: widget.isReceivables,
              ),
            _MoreLink(
              label: widget.isReceivables
                  ? l10n.kpiDrawerViewAllParties
                  : l10n.kpiDrawerViewAllVendors,
              onTap: () => _pushFull(
                widget.hostContext,
                widget.isReceivables
                    ? const PartiesPage()
                    : const VendorsPage(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CounterpartyTile extends StatelessWidget {
  const _CounterpartyTile({required this.party, required this.isReceivables});
  final BreakdownParty party;
  final bool isReceivables;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      // Strip the default ExpansionTile dividers so it sits flush on canvas.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSizes.sm),
        title: Text(
          party.name,
          style: DashText.bodyMd,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${isReceivables ? l10n.kpiDrawerReceived : l10n.kpiDrawerPaid}: '
          '${inr.format(party.settled)} · ${l10n.kpiDrawerBilled}: ${inr.format(party.billed)}',
          style: DashText.bodySm,
        ),
        trailing: Text(
          inr.format(party.outstanding),
          style: DashText.bodyMd.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: tabularFigures,
          ),
        ),
        children: [
          for (final inv in party.invoices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  AppIcon(
                    AppIcons.descriptionOutlined,
                    size: AppSizes.iconSm,
                    color: AppColors.subtle,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      '${inv.invoiceNo} · ${_fmtDate(inv.invoiceDate)}',
                      style: DashText.bodySm,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    inr.format(inv.total),
                    style: DashText.bodySm.copyWith(
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── shared status blocks ───────────────────────────────────────────────

class _Grabber extends StatelessWidget {
  const _Grabber();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.hairline,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.lg),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            height: 48,
            margin: const EdgeInsets.only(bottom: AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.kpiDrawerLoadError,
              style: DashText.bodyMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.md),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.kpiDrawerRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Text(
          message,
          style: DashText.bodyMd.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _MoreLink extends StatelessWidget {
  const _MoreLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.md),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: DashText.bodyMd.copyWith(
                  color: AppColors.brandStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              AppIcon(
                AppIcons.openInNewRounded,
                size: 14,
                color: AppColors.brandStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final DateFormat _dateFmt = DateFormat('d MMM yyyy', 'en_IN');
String _fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? '—' : _dateFmt.format(d);
}

/// Close the sheet, then navigate on the host (dashboard) navigator — the
/// "View full …" footer link out to the relevant full-page screen.
void _pushFull(BuildContext hostContext, Widget page) {
  Navigator.of(hostContext).pop(); // dismiss the sheet
  dashPush(hostContext, page);
}
