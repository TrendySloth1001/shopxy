import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/analytics/data/models/analytics.dart';
import 'package:shopxy/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Per-flash-deal report — sold count + traffic per hour during the
/// scheduled window. Renders the time series as a custom-painted bar
/// chart (no chart dependency); good enough for the merchant glance.
class FlashDealAnalyticsPage extends StatefulWidget {
  const FlashDealAnalyticsPage({super.key, required this.flashSaleId});
  final int flashSaleId;

  @override
  State<FlashDealAnalyticsPage> createState() => _FlashDealAnalyticsPageState();
}

class _FlashDealAnalyticsPageState extends State<FlashDealAnalyticsPage> {
  FlashDealAnalytics? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result =
        await context.read<AnalyticsProvider>().loadFlashDeal(widget.flashSaleId);
    if (!mounted) return;
    setState(() {
      _data = result;
      _loading = false;
      if (result == null) _error = 'Failed to load';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Flash deal analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(child: Text(_error ?? 'No data'))
              : _Body(data: _data!),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final FlashDealAnalytics data;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    final pct = data.stockLimit == 0
        ? 0.0
        : (data.soldCount / data.stockLimit).clamp(0.0, 1.0);
    final maxValue = data.series.fold<int>(
      0,
      (m, p) => [m, p.sold, p.taps, p.views]
          .reduce((a, b) => a > b ? a : b),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.huge,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: ShapeDecoration(
            color: AppColors.white,
            shape: AppShapes.squircle(AppSizes.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.productName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${df.format(data.startAt)}  →  ${df.format(data.endAt)}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: AppSizes.md),
              LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.heroPanel,
                valueColor: const AlwaysStoppedAnimation(AppColors.brand),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                '${data.soldCount} / ${data.stockLimit} sold',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        if (data.series.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusMd),
            ),
            child: const Text(
              'No traffic during this window yet.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          _BarChart(series: data.series, maxValue: maxValue == 0 ? 1 : maxValue),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.series, required this.maxValue});
  final List<FlashDealSeriesPoint> series;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.Hm();
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
            child: Row(
              children: const [
                _LegendDot(color: AppColors.brand, label: 'Sold'),
                SizedBox(width: AppSizes.md),
                _LegendDot(color: AppColors.accentIndigo, label: 'Taps'),
                SizedBox(width: AppSizes.md),
                _LegendDot(color: AppColors.accentTeal, label: 'Views'),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in series)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _Bar(
                                  height: 200 * (p.sold / maxValue),
                                  color: AppColors.brand,
                                ),
                                _Bar(
                                  height: 200 * (p.taps / maxValue),
                                  color: AppColors.accentIndigo,
                                ),
                                _Bar(
                                  height: 200 * (p.views / maxValue),
                                  color: AppColors.accentTeal,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            df.format(p.hour.toLocal()),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
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

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});
  final double height;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        width: 6,
        height: height.clamp(2.0, 200.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
