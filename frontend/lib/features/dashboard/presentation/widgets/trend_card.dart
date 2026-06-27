import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/trend_chart.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

final _modeColors = <String, Color>{
  'UPI': AppColors.accentTeal,
  'CASH': AppColors.success,
  'CARD': AppColors.accentIndigo,
  'NEFT': AppColors.accentAmber,
  'RTGS': AppColors.accentRose,
  'CHEQUE': AppColors.brand,
};

String _titleCase(String m) =>
    m.isEmpty ? m : m[0].toUpperCase() + m.substring(1).toLowerCase();

String _fmtDay(String key) {
  final d = DateTime.tryParse(key);
  if (d == null) return key;
  return DateFormat('d MMM').format(d);
}

/// Sales trend with comparison lines + a line per payment mode. Mirrors
/// `components/trend-card.tsx`.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.trend});
  final DashboardTrend trend;

  @override
  Widget build(BuildContext context) {
    final labels = trend.labels.map(_fmtDay).toList();
    final total = trend.sales.fold<double>(0, (s, v) => s + v);

    final series = <TrendSeriesData>[
      TrendSeriesData(
          key: 'sales',
          label: 'Sales',
          color: AppColors.brand,
          values: trend.sales),
      for (final p in trend.paymentSeries)
        TrendSeriesData(
          key: 'pay:${p.mode}',
          label: _titleCase(p.mode),
          color: _modeColors[p.mode.toUpperCase()] ?? AppColors.subtle,
          values: p.values,
        ),
    ];

    final comparisons = <TrendSeriesData>[];
    if (trend.previous.any((v) => v != 0)) {
      comparisons.add(TrendSeriesData(
          key: 'previous',
          label: 'Previous',
          color: AppColors.subtle,
          values: trend.previous));
    }
    if (trend.purchases.any((v) => v != 0)) {
      comparisons.add(TrendSeriesData(
          key: 'purchases',
          label: 'Purchases',
          color: AppColors.accentAmber,
          values: trend.purchases));
    }
    if (trend.returns.any((v) => v != 0)) {
      comparisons.add(TrendSeriesData(
          key: 'returns',
          label: 'Returns',
          color: AppColors.accentRose,
          values: trend.returns));
    }

    final all = [...series, ...comparisons];

    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Sales trend'),
          const SizedBox(height: AppSizes.xs),
          Text(inr.format(total),
              style: DashText.titleMd.copyWith(fontFeatures: tabularFigures)),
          const SizedBox(height: AppSizes.md),
          TrendChart(
            series: all,
            xLabels: labels,
            formatValue: (v) => inr.format(v),
            formatTick: (v) => inrCompact.format(v),
            initialHidden: comparisons.map((c) => c.key).toList(),
          ),
        ],
      ),
    );
  }
}
