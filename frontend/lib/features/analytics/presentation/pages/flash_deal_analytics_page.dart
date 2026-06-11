import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/analytics/data/models/analytics.dart';
import 'package:shopxy/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';

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
          ? const _FlashDealSkeleton()
          : _data == null
              ? Center(child: Text(_error ?? 'No data'))
              : _Body(data: _data!),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _FlashDealSkeleton extends StatelessWidget {
  const _FlashDealSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.huge,
      ),
      children: const [
        _TopCardSkeleton(),
        SizedBox(height: AppSizes.lg),
        _BarChartSkeleton(),
      ],
    );
  }
}

/// Mirrors the top summary card: product name, date range, progress bar, sold count.
class _TopCardSkeleton extends StatelessWidget {
  const _TopCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product name — titleMedium (~20 dp tall, 60 % width)
          AppShimmerLine(widthFactor: 0.6, height: 20),
          const SizedBox(height: AppSizes.xs),
          // Date range — bodyMedium (~14 dp tall, 80 % width)
          AppShimmerLine(widthFactor: 0.8, height: 14),
          const SizedBox(height: AppSizes.md),
          // LinearProgressIndicator height bar (full width, AppSizes.sm tall)
          AppShimmerLine(widthFactor: 1.0, height: AppSizes.sm),
          const SizedBox(height: AppSizes.sm),
          // "sold count" text — bodyMedium (~14 dp, 40 % width)
          AppShimmerLine(widthFactor: 0.4, height: 14),
        ],
      ),
    );
  }
}

/// Mirrors the bar-chart card: legend labels + grid of bar columns.
class _BarChartSkeleton extends StatelessWidget {
  const _BarChartSkeleton();

  // Render 12 skeleton bar-group columns.
  static const int _barCount = 12;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend row — three shimmer pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
            child: Row(
              children: [
                AppShimmerLine(widthFactor: 0.12, height: 14),
                const SizedBox(width: AppSizes.md),
                AppShimmerLine(widthFactor: 0.12, height: 14),
                const SizedBox(width: AppSizes.md),
                AppShimmerLine(widthFactor: 0.14, height: 14),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          // Bar chart area
          SizedBox(
            height: AppSizes.qrCodeSize,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < _barCount; i++)
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Three bars per column with varying heights
                          AppShimmerBox(
                            width: double.infinity,
                            height: AppSizes.qrCodeSize *
                                _barHeightFactor(i, 0),
                            radius: AppSizes.radiusXs,
                          ),
                          const SizedBox(height: 2),
                          // Hour label placeholder
                          AppShimmerLine(widthFactor: 0.8, height: 10),
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

  /// Produces a varied height factor (0.2–0.85) so the skeleton looks organic
  /// rather than a flat line.
  static double _barHeightFactor(int index, int offset) {
    const factors = <double>[
      0.4, 0.65, 0.3, 0.75, 0.5, 0.85,
      0.35, 0.6, 0.45, 0.7, 0.25, 0.55,
    ];
    return factors[(index + offset) % factors.length];
  }
}

// ---------------------------------------------------------------------------
// Real content
// ---------------------------------------------------------------------------

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
              const SizedBox(height: AppSizes.xs),
              Text(
                '${df.format(data.startAt.toLocal())}  →  ${df.format(data.endAt.toLocal())}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSizes.md),
              LinearProgressIndicator(
                value: pct,
                minHeight: AppSizes.sm,
                backgroundColor: AppColors.heroPanel,
                valueColor: const AlwaysStoppedAnimation(AppColors.brand),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                '${data.soldCount} / ${data.stockLimit} sold',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
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
            child: Text(
              'No traffic during this window yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
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
            height: AppSizes.qrCodeSize,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in series)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _Bar(
                                  height:
                                      AppSizes.qrCodeSize * (p.sold / maxValue),
                                  color: AppColors.brand,
                                ),
                                _Bar(
                                  height:
                                      AppSizes.qrCodeSize * (p.taps / maxValue),
                                  color: AppColors.accentIndigo,
                                ),
                                _Bar(
                                  height:
                                      AppSizes.qrCodeSize * (p.views / maxValue),
                                  color: AppColors.accentTeal,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            df.format(p.hour.toLocal()),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.muted),
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
        width: AppSizes.sm,
        height: height.clamp(2.0, AppSizes.qrCodeSize),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSizes.radiusXs),
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
          width: AppSizes.md,
          height: AppSizes.md,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSizes.sm),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
