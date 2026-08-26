import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/providers/product_catalogue.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';

Future<void> showProductPicker(
  BuildContext context, {
  required bool sale,
  required void Function(Product) onAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _ProductPickerSheet(sale: sale, onAdd: onAdd),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.sale, required this.onAdd});

  final bool sale;
  final void Function(Product) onAdd;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Product> _results = [];
  bool _loading = false;
  String? _error;

  final Map<String, int> _added = {};

  @override
  void initState() {
    super.initState();
    _loadFromServer('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final catalogue = context.read<ProductCatalogue>();
    if (catalogue.isSearchable && value.trim().isNotEmpty) {
      _debounce?.cancel();
      setState(() {
        _results = catalogue.search(value, limit: 50);
        _loading = false;
        _error = null;
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(AppDurations.searchDebounce, () {
      if (mounted) _loadFromServer(value);
    });
  }

  Future<void> _loadFromServer(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final result = await ds.getProducts(
        search: query.trim().isEmpty ? null : query,
        limit: 50,
      );
      if (!mounted) return;
      setState(() => _results = result.products);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _add(Product product) {
    widget.onAdd(product);
    setState(() => _added[product.id] = (_added[product.id] ?? 0) + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.of(context).size.height * 0.8;
    final addedCount = _added.values.fold<int>(0, (sum, n) => sum + n);

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSizes.md),
            Container(
              width: AppSizes.handleWidth,
              height: AppSizes.handleHeight,
              decoration: ShapeDecoration(
                color: AppColors.hairline,
                shape: AppShapes.squircle(AppSizes.radiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.productsPickerTitle,
                      style: theme.textTheme.titleMedium?.bold,
                    ),
                  ),
                  if (addedCount > 0)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.productsPickerDone(addedCount)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: AppSearchBar(
                hint: l10n.productsPickerSearchHint,
                controller: _search,
                onChanged: _onQueryChanged,
                autofocus: false,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(child: _body(theme, l10n)),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme, AppLocalizations l10n) {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.inventory2Outlined,
                size: AppSizes.iconXl,
                color: AppColors.muted,
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                _search.text.trim().isEmpty
                    ? l10n.productsPickerEmpty
                    : l10n.productsPickerNoMatches,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const AppDivider(),
      itemBuilder: (context, i) {
        final p = _results[i];
        final count = _added[p.id] ?? 0;
        final price = widget.sale ? p.sellingPrice : p.purchasePrice;
        return ListTile(
          title: Text(p.name),
          subtitle: Text(
            '${p.sku}  ·  ${l10n.productsPickerInStock(_qty(p.stockQuantity), p.unit)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppStrings.currencySymbol}${price.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: AppSizes.sm),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 2,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.brandSoft,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Text(
                    '×$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.brandStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                AppIcon(AppIcons.addRounded, color: AppColors.subtle),
            ],
          ),
          onTap: () => _add(p),
        );
      },
    );
  }

  String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
