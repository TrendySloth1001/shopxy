import 'package:flutter/material.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/infographic_pie.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';

/// Ranked analytics as infographic pie charts. Top categories + top products
/// sit side by side on wide screens; slow movers spans full width.
/// Mirrors `components/analytics.tsx`.
class Analytics extends StatelessWidget {
  const Analytics({super.key, required this.insights});
  final DashboardInsights insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _PieCard(
      title: l10n.dashboardTopCategories,
      child: InfographicPie(
        rows: insights.topCategories
            .map((c) => PieRow(label: c.name, value: c.revenue))
            .toList(),
        palette: piePaletteA,
        formatValue: (v) => inr.format(v),
        subject: l10n.dashboardSubjectCategorySales,
        itemNoun: l10n.dashboardNounCategories,
      ),
    );

    final products = _PieCard(
      title: l10n.dashboardTopProducts,
      child: InfographicPie(
        rows: insights.topProducts
            .map((p) => PieRow(label: p.name, value: p.revenue))
            .toList(),
        palette: piePaletteB,
        formatValue: (v) => inr.format(v),
        subject: l10n.dashboardSubjectProductSales,
        itemNoun: l10n.dashboardNounProducts,
      ),
    );

    final slowMovers = _PieCard(
      title: l10n.dashboardSlowMovers,
      hint: l10n.dashboardSlowMoversHint,
      child: InfographicPie(
        rows: insights.slowMovers
            .map((m) => PieRow(label: m.name, value: m.stock))
            .toList(),
        palette: piePaletteC,
        formatValue: (v) => l10n.dashboardUnitsValue(v.toStringAsFixed(0)),
        subject: l10n.dashboardSubjectIdleStock,
        itemNoun: l10n.dashboardNounProducts,
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= Bp.xl) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: categories),
                  const SizedBox(width: AppSizes.md),
                  Expanded(child: products),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              slowMovers,
            ],
          );
        }
        return Column(
          children: [
            categories,
            const SizedBox(height: AppSizes.md),
            products,
            const SizedBox(height: AppSizes.md),
            slowMovers,
          ],
        );
      },
    );
  }
}

class _PieCard extends StatelessWidget {
  const _PieCard({required this.title, required this.child, this.hint});
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(title),
          if (hint != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(hint!, style: DashText.bodySm),
          ],
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}
