import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/analytics/data/models/analytics.dart';
import 'package:shopxy/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Merchant-facing analytics dashboard. One scroll: date range, KPI
/// strip, per-product table. All sorting + range manipulation lives in
/// the provider — the page is a thin renderer.
class MerchantAnalyticsPage extends StatefulWidget {
  const MerchantAnalyticsPage({super.key});

  @override
  State<MerchantAnalyticsPage> createState() => _MerchantAnalyticsPageState();
}

class _MerchantAnalyticsPageState extends State<MerchantAnalyticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AnalyticsProvider>().load();
    });
  }

  Future<void> _pickRange() async {
    final provider = context.read<AnalyticsProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: provider.from, end: provider.to),
    );
    if (picked == null || !mounted) return;
    provider.setRange(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticsProvider>();
    final df = DateFormat.yMMMd();
    final data = provider.data;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : provider.load,
          ),
        ],
      ),
      body: provider.isLoading && data == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.huge,
                ),
                children: [
                  _RangeBar(
                    label:
                        '${df.format(provider.from)}  →  ${df.format(provider.to)}',
                    onTap: _pickRange,
                  ),
                  const SizedBox(height: AppSizes.lg),
                  if (data != null) ...[
                    _KpiStrip(totals: data.totals),
                    const SizedBox(height: AppSizes.lg),
                    Text(
                      'By product',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    if (data.products.isEmpty)
                      const _Empty(text: 'No active products yet')
                    else
                      _ProductTable(
                        rows: provider.sortedProducts,
                        sortKey: provider.sortKey,
                        sortAsc: provider.sortAsc,
                        onSort: provider.sortBy,
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: AppSizes.iconMd),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(label)),
            const Icon(Icons.tune, size: AppSizes.iconMd),
          ],
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.totals});
  final AnalyticsTotals totals;

  String _pct(double v) => '${(v * 100).toStringAsFixed(2)}%';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        _Kpi(label: 'Impressions', value: '${totals.impressions}'),
        _Kpi(label: 'Taps', value: '${totals.taps}'),
        _Kpi(label: 'Views', value: '${totals.views}'),
        _Kpi(label: 'Add to cart', value: '${totals.addToCart}'),
        _Kpi(label: 'Purchases', value: '${totals.purchases}'),
        _Kpi(label: 'Wishlist', value: '${totals.wishlistAdd}'),
        _Kpi(label: 'CTR', value: _pct(totals.ctr)),
        _Kpi(label: 'CVR', value: _pct(totals.cvr)),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.muted),
      ),
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.rows,
    required this.sortKey,
    required this.sortAsc,
    required this.onSort,
  });
  final List<ProductAnalyticsRow> rows;
  final AnalyticsSortKey sortKey;
  final bool sortAsc;
  final void Function(AnalyticsSortKey) onSort;

  int _sortColumnIndex() {
    switch (sortKey) {
      case AnalyticsSortKey.product:
        return 0;
      case AnalyticsSortKey.impressions:
        return 1;
      case AnalyticsSortKey.taps:
        return 2;
      case AnalyticsSortKey.views:
        return 3;
      case AnalyticsSortKey.addToCart:
        return 4;
      case AnalyticsSortKey.purchases:
        return 5;
      case AnalyticsSortKey.ctr:
        return 6;
      case AnalyticsSortKey.cvr:
        return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumnIndex(),
        sortAscending: sortAsc,
        columns: [
          DataColumn(
            label: const Text('Product'),
            onSort: (_, _) => onSort(AnalyticsSortKey.product),
          ),
          DataColumn(
            label: const Text('Imp'),
            numeric: true,
            onSort: (_, _) => onSort(AnalyticsSortKey.impressions),
          ),
          DataColumn(
            label: const Text('Taps'),
            numeric: true,
            onSort: (_, _) => onSort(AnalyticsSortKey.taps),
          ),
          DataColumn(
            label: const Text('Views'),
            numeric: true,
            onSort: (_, _) => onSort(AnalyticsSortKey.views),
          ),
          DataColumn(
            label: const Text('ATC'),
            numeric: true,
            onSort: (_, _) => onSort(AnalyticsSortKey.addToCart),
          ),
          DataColumn(
            label: const Text('Buys'),
            numeric: true,
            onSort: (_, _) => onSort(AnalyticsSortKey.purchases),
          ),
          DataColumn(
            label: const Text('CTR'),
            numeric: true,
            onSort: (_, _) => onSort(AnalyticsSortKey.ctr),
          ),
          DataColumn(
            label: const Text('CVR'),
            numeric: true,
            onSort: (_, _) => onSort(AnalyticsSortKey.cvr),
          ),
        ],
        rows: rows
            .map(
              (r) => DataRow(
                cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        r.productName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text('${r.impressions}')),
                  DataCell(Text('${r.taps}')),
                  DataCell(Text('${r.views}')),
                  DataCell(Text('${r.addToCart}')),
                  DataCell(Text('${r.purchases}')),
                  DataCell(Text('${(r.ctr * 100).toStringAsFixed(1)}%')),
                  DataCell(Text('${(r.cvr * 100).toStringAsFixed(1)}%')),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
