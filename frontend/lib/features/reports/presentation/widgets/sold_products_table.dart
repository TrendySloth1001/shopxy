import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:shopxy/features/reports/domain/entities/sales_report.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';

class SoldProductsTable extends StatefulWidget {
  const SoldProductsTable({super.key, required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  @override
  State<SoldProductsTable> createState() => _SoldProductsTableState();
}

const int _soldPageSize = 25;

class _SoldProductsTableState extends State<SoldProductsTable> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _search = '';

  List<SoldProduct> _products = const [];
  int _total = 0;
  SoldTotals _totals = const SoldTotals(
    salesCount: 0,
    totalQuantity: 0,
    totalAmount: 0,
  );
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SoldProductsTable old) {
    super.didUpdateWidget(old);
    if (old.from != widget.from || old.to != widget.to) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(AppDurations.searchDebounce, () {
      if (!mounted) return;
      _search = v.trim();
      _load();
    });
  }

  ReportsRemoteDataSource get _ds => context.read<ReportsRemoteDataSource>();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _expanded = null;
    });
    try {
      final res = await _ds.soldProducts(
        widget.from,
        widget.to,
        page: 1,
        limit: _soldPageSize,
        search: _search,
      );
      if (!mounted) return;
      setState(() {
        _products = res.data;
        _total = res.pagination.total;
        _totals = res.totals;
        _page = 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _products = const [];
        _total = 0;
        _totals = const SoldTotals(
          salesCount: 0,
          totalQuantity: 0,
          totalAmount: 0,
        );
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final next = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final res = await _ds.soldProducts(
        widget.from,
        widget.to,
        page: next,
        limit: _soldPageSize,
        search: _search,
      );
      if (!mounted) return;
      setState(() {
        _products = [..._products, ...res.data];
        _total = res.pagination.total;
        _page = next;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasMore = _products.length < _total;
    final searching = _search.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.xl,
            AppSizes.lg,
            AppSizes.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  l10n.reportsProductsSold,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              if (!_loading && _total > 0)
                Text(
                  l10n.reportsCountOfTotal('${_products.length}', '$_total'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.subtle,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: AppSearchBar(
            hint: l10n.reportsSearchByProductOrSku,
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            debounce: Duration.zero,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: ShapeDecoration(
                color: AppColors.errorSoft,
                shape: AppShapes.squircle(AppSizes.radiusMd),
              ),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          )
        else if (_products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.lg,
            ),
            child: Text(
              searching
                  ? l10n.reportsNoSoldProductsMatch(_search)
                  : l10n.reportsNoProductsSoldInRange,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.subtle,
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: AppShapes.squircle(AppSizes.radiusMd),
              ),
              child: Container(
                decoration: ShapeDecoration(
                  shape: AppShapes.squircle(
                    AppSizes.radiusMd,
                    side: BorderSide(color: AppColors.hairline),
                  ),
                ),
                child: Column(
                  children: [
                    for (final p in _products)
                      _ProductRow(
                        product: p,
                        from: widget.from,
                        to: widget.to,
                        expanded: _expanded == p.productId,
                        onToggle: () => setState(
                          () => _expanded = _expanded == p.productId
                              ? null
                              : p.productId,
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.heroPanel,
                        border: Border(
                          top: BorderSide(color: AppColors.hairline),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.reportsColTotal,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Text(
                            '${_totals.salesCount == 1 ? l10n.reportsSaleCountOne('${_totals.salesCount}') : l10n.reportsSaleCountOther('${_totals.salesCount}')} · ${fmtQty(_totals.totalQuantity)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSizes.md),
                          Text(
                            _money().format(_totals.totalAmount),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: hasMore
                ? OutlinedButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(
                      _loadingMore
                          ? l10n.reportsLoading
                          : l10n.reportsLoadMore(
                              '${_total - _products.length}',
                            ),
                    ),
                  )
                : Text(
                    _total == 1
                        ? l10n.reportsAllProductsShownOne('$_total')
                        : l10n.reportsAllProductsShownOther('$_total'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.subtle,
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.from,
    required this.to,
    required this.expanded,
    required this.onToggle,
  });
  final SoldProduct product;
  final DateTime from;
  final DateTime to;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit = product.unit ?? '';
    final tone = _toneFor(
      product.productSku ?? product.productName ?? product.productId,
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Container(
              color: expanded ? AppColors.surfaceTint : null,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: AppIcon(
                          AppIcons.chevronRightRounded,
                          size: AppSizes.iconMd,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Container(
                        width: AppSizes.iconXl,
                        height: AppSizes.iconXl,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: AppColors.tileBg(tone.$2),
                          shape: AppShapes.squircle(AppSizes.radiusSm),
                        ),
                        child: AppIcon(
                          AppIcons.inventory2Outlined,
                          size: AppSizes.iconSm,
                          color: tone.$1,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.productName ??
                                  l10n.reportsProductFallback,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            if ((product.productSku ?? '').isNotEmpty)
                              Text(
                                product.productSku!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.subtle,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        _money().format(product.totalAmount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Padding(
                    padding: const EdgeInsets.only(left: AppSizes.xxl),
                    child: Row(
                      children: [
                        _Chip(
                          label: product.salesCount == 1
                              ? l10n.reportsSaleCountOne(
                                  '${product.salesCount}',
                                )
                              : l10n.reportsSaleCountOther(
                                  '${product.salesCount}',
                                ),
                          tone: _countTone(product.salesCount),
                        ),
                        const SizedBox(width: AppSizes.xs),
                        _Chip(
                          label:
                              '${fmtQty(product.totalQuantity)}${unit.isNotEmpty ? " $unit" : ""}',
                          tone: _qtyTone(product.totalQuantity),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _ProductTimeline(from: from, to: to, product: product),
        ],
      ),
    );
  }
}

class _ProductTimeline extends StatefulWidget {
  const _ProductTimeline({
    required this.from,
    required this.to,
    required this.product,
  });
  final DateTime from;
  final DateTime to;
  final SoldProduct product;

  @override
  State<_ProductTimeline> createState() => _ProductTimelineState();
}

const int _timelinePageSize = 15;

class _ProductTimelineState extends State<_ProductTimeline> {
  List<SoldItem> _items = const [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ReportsRemoteDataSource get _ds => context.read<ReportsRemoteDataSource>();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _ds.soldItems(
        widget.from,
        widget.to,
        productId: widget.product.productId,
        page: 1,
        limit: _timelinePageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = res.data;
        _total = res.pagination.total;
        _page = 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _items = const [];
        _total = 0;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final next = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final res = await _ds.soldItems(
        widget.from,
        widget.to,
        productId: widget.product.productId,
        page: next,
        limit: _timelinePageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...res.data];
        _total = res.pagination.total;
        _page = next;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = widget.product;
    final unit = p.unit ?? '';
    final hasMore = _items.length < _total;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.md),
              child: Center(
                child: SizedBox(
                  width: AppSizes.iconMd,
                  height: AppSizes.iconMd,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            )
          else if (_items.isEmpty)
            Text(
              l10n.reportsNoSalesForProduct,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.subtle,
              ),
            )
          else
            for (final ev in _items) _TimelineRow(item: ev, unit: unit),
          if (!_loading && hasMore)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.sm),
              child: OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(
                  _loadingMore
                      ? l10n.reportsLoading
                      : l10n.reportsLoadMore('${_total - _items.length}'),
                ),
              ),
            ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.sm),
              child: Column(
                children: [
                  Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n.reportsColTotal} · ${p.salesCount == 1 ? l10n.reportsSaleCountOne('${p.salesCount}') : l10n.reportsSaleCountOther('${p.salesCount}')} · ${fmtQty(p.totalQuantity)}${unit.isNotEmpty ? " $unit" : ""}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.subtle,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        _money().format(p.totalAmount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.unit});
  final SoldItem item;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = item.soldAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          AppIcon(
            AppIcons.scheduleRounded,
            size: AppSizes.iconSm,
            color: _recencyColor(when),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when == null
                      ? '—'
                      : DateFormat('d MMM yyyy, h:mm a').format(when.toLocal()),
                  style: theme.textTheme.bodySmall,
                ),
                if ((item.invoiceNo ?? '').isNotEmpty)
                  Text(
                    item.invoiceNo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.subtle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          _Chip(
            label: '${fmtQty(item.quantity)}${unit.isNotEmpty ? " $unit" : ""}',
            tone: _qtyTone(item.quantity),
          ),
          const SizedBox(width: AppSizes.sm),
          Text(
            _money().format(item.total),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.tone});
  final String label;
  final (Color, Color) tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 1),
      decoration: ShapeDecoration(
        color: tone.$2,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tone.$1,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

NumberFormat _money() =>
    NumberFormat.currency(symbol: AppStrings.currencySymbol, decimalDigits: 0);

String fmtQty(double q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

(Color, Color) _toneFor(String key) {
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final tones = <(Color, Color)>[
    (AppColors.accentTeal, AppColors.accentTealSoft),
    (AppColors.accentIndigo, AppColors.accentIndigoSoft),
    (AppColors.accentAmber, AppColors.accentAmberSoft),
    (AppColors.accentRose, AppColors.accentRoseSoft),
    (AppColors.brandStrong, AppColors.brandSoft),
  ];
  return tones[h % tones.length];
}

(Color, Color) _qtyTone(double q) {
  if (q >= 5) return (AppColors.brandStrong, AppColors.brandSoft);
  if (q >= 2) return (AppColors.info, AppColors.infoSoft);
  return (AppColors.muted, AppColors.surfaceTint);
}

(Color, Color) _countTone(int c) {
  if (c >= 10) return (AppColors.brandStrong, AppColors.brandSoft);
  if (c >= 3) return (AppColors.info, AppColors.infoSoft);
  return (AppColors.muted, AppColors.surfaceTint);
}

Color _recencyColor(DateTime? when) {
  if (when == null) return AppColors.subtle;
  final days = DateTime.now().difference(when).inHours / 24;
  if (days < 1) return AppColors.success;
  if (days < 7) return AppColors.info;
  return AppColors.subtle;
}
