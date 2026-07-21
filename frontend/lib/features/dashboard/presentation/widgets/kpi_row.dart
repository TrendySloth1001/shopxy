import 'package:flutter/material.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/kpi_drill_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Hero KPI row — what you sold, kept, are owed, and owe. 2 columns on
/// phones, 4 on wide screens. Mirrors `components/kpi-row.tsx`. Each card
/// opens a drill-down bottom sheet (the mobile take on the web slide-over),
/// not a full-page jump.
class KpiRow extends StatelessWidget {
  const KpiRow({super.key, required this.kpis, required this.period});
  final DashboardKpis kpis;
  final DashboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = responsiveCols(c.maxWidth, base: 2, lg: 4);
        return ResponsiveGrid(
          columns: cols,
          children: [
            _KpiCard(
              icon: AppIcons.currencyRupeeRounded,
              iconColor: AppColors.brandStrong,
              label: l10n.dashboardSales,
              value: inr.format(kpis.sales.value),
              footer: DeltaChip(value: kpis.sales.deltaPct),
              onTap: () => showKpiDrillSheet(context,
                  kind: KpiDrillKind.sales, period: period),
            ),
            _KpiCard(
              icon: AppIcons.trendingUpRounded,
              iconColor: AppColors.success,
              label: l10n.dashboardNetProfit,
              value: inr.format(kpis.profit.value),
              footer: Row(
                children: [
                  DeltaChip(value: kpis.profit.deltaPct),
                  const SizedBox(width: AppSizes.sm),
                  Flexible(
                    child: Text(
                      l10n.dashboardMarginPct('${kpis.profit.margin}'),
                      style: DashText.labelMd,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              onTap: () => showKpiDrillSheet(context,
                  kind: KpiDrillKind.profit, period: period),
            ),
            _KpiCard(
              icon: AppIcons.southWestRounded,
              iconColor: AppColors.accentIndigo,
              label: l10n.dashboardReceivables,
              value: inr.format(kpis.receivables.outstanding),
              footer: Text(
                kpis.receivables.count == 1
                    ? l10n.dashboardOnePartyOwesYou
                    : l10n.dashboardPartiesOweYou('${kpis.receivables.count}'),
                style: DashText.labelMd,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => showKpiDrillSheet(context,
                  kind: KpiDrillKind.receivables, period: period),
            ),
            _KpiCard(
              icon: AppIcons.northEastRounded,
              iconColor: AppColors.accentAmber,
              label: l10n.dashboardPayables,
              value: inr.format(kpis.payables.outstanding),
              footer: Text(
                kpis.payables.count == 1
                    ? l10n.dashboardOneVendorToPay
                    : l10n.dashboardVendorsToPay('${kpis.payables.count}'),
                style: DashText.labelMd,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => showKpiDrillSheet(context,
                  kind: KpiDrillKind.payables, period: period),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.footer,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget footer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSizes.iconSm, color: iconColor),
              const SizedBox(width: AppSizes.sm),
              Flexible(
                child: Text(label,
                    style: DashText.labelMd, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: DashText.headlineMd.copyWith(fontFeatures: tabularFigures),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          footer,
        ],
      ),
    );
  }
}
