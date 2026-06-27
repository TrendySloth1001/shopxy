import 'package:flutter/material.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/infographic_pie.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';

/// Ranked analytics as infographic pie charts. Top categories + top products
/// sit side by side on wide screens; slow movers spans full width.
/// Mirrors `components/analytics.tsx`.
class Analytics extends StatelessWidget {
  const Analytics({super.key, required this.insights});
  final DashboardInsights insights;

  @override
  Widget build(BuildContext context) {
    final categories = _PieCard(
      title: 'Top categories',
      child: InfographicPie(
        rows: insights.topCategories
            .map((c) => PieRow(label: c.name, value: c.revenue))
            .toList(),
        palette: piePaletteA,
        formatValue: (v) => inr.format(v),
        subject: 'category sales',
        itemNoun: 'categories',
      ),
    );

    final products = _PieCard(
      title: 'Top products',
      child: InfographicPie(
        rows: insights.topProducts
            .map((p) => PieRow(label: p.name, value: p.revenue))
            .toList(),
        palette: piePaletteB,
        formatValue: (v) => inr.format(v),
        subject: 'product sales',
        itemNoun: 'products',
      ),
    );

    final slowMovers = _PieCard(
      title: 'Slow movers',
      hint: 'Share of idle in-stock units — capital that isn’t moving.',
      child: InfographicPie(
        rows: insights.slowMovers
            .map((m) => PieRow(label: m.name, value: m.stock))
            .toList(),
        palette: piePaletteC,
        formatValue: (v) => '${v.toStringAsFixed(0)} units',
        subject: 'idle stock',
        itemNoun: 'products',
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
