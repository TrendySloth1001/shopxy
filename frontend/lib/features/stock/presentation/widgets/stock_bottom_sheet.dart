import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/presentation/providers/stock_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

// Vendor model scoped to this widget (sourced from /stock/suppliers)
typedef _SV = SupplierVendor;

class StockBottomSheet extends StatefulWidget {
  const StockBottomSheet({
    super.key,
    required this.product,
    this.initialType = 'STOCK_IN',
  });

  final Product product;
  final String initialType;

  @override
  State<StockBottomSheet> createState() => _StockBottomSheetState();
}

class _StockBottomSheetState extends State<StockBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  String _purchasePriceMode = 'WEIGHTED_AVERAGE';
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _supplier = TextEditingController();
  final _supplierFocusNode = FocusNode();
  final _note = TextEditingController();

  // Vendor selection — structured vendors from /stock/suppliers
  List<_SV> _vendors = const [];
  _SV? _selectedVendor;
  List<String> _freeTextOptions = const [];
  Timer? _supplierDebounce;
  bool _isLoadingSuppliers = false;
  String _lastSupplierQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_type == 'STOCK_IN') {
      _unitPrice.text = widget.product.purchasePrice.toStringAsFixed(2);
      _loadSupplierOptions();
    }
    _unitPrice.addListener(_refreshForm);
    _quantity.addListener(_refreshForm);
    _supplier.addListener(_onSupplierInputChanged);
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitPrice.dispose();
    _supplier.removeListener(_onSupplierInputChanged);
    _supplier.dispose();
    _supplierFocusNode.dispose();
    _supplierDebounce?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _refreshForm() {
    if (mounted) setState(() {});
  }

  void _onSupplierInputChanged() {
    if (_type != 'STOCK_IN') return;
    // If user types manually, clear structured vendor selection
    if (_selectedVendor != null && _supplier.text != _selectedVendor!.name) {
      _selectedVendor = null;
    }
    final query = _supplier.text.trim();
    if (query == _lastSupplierQuery) return;
    _lastSupplierQuery = query;
    _supplierDebounce?.cancel();
    _supplierDebounce = Timer(const Duration(milliseconds: 240), () {
      _loadSupplierOptions(query: query.isEmpty ? null : query);
    });
  }

  Future<void> _loadSupplierOptions({String? query}) async {
    if (_type != 'STOCK_IN') return;
    setState(() => _isLoadingSuppliers = true);
    try {
      final ds = context.read<StockRemoteDataSource>();
      var result = await ds.getSuppliers(query: query, productId: widget.product.id, limit: 12);
      // If no product-specific vendors, fall back to all vendors
      if (result.vendors.isEmpty && result.freeTextSuppliers.isEmpty) {
        result = await ds.getSuppliers(query: query, limit: 12);
      }
      if (!mounted) return;
      setState(() {
        _vendors = result.vendors;
        _freeTextOptions = result.freeTextSuppliers;
        _isLoadingSuppliers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSuppliers = false);
    }
  }

  void _selectVendor(_SV vendor) {
    setState(() {
      _selectedVendor = vendor;
      _supplier.text = vendor.name;
    });
    _supplierFocusNode.unfocus();
  }

  void _clearVendor() {
    setState(() {
      _selectedVendor = null;
      _supplier.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final parsedUnitPrice = _parseDouble(_unitPrice.text);
    final parsedQuantity = _parseDouble(_quantity.text);
    if (parsedQuantity == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    try {
      await context.read<StockProvider>().addStock(
        productId: widget.product.id,
        type: _type,
        quantity: parsedQuantity,
        unitPrice: _type == 'STOCK_IN' ? parsedUnitPrice : null,
        vendorId: _type == 'STOCK_IN' ? _selectedVendor?.id : null,
        supplierName: _type == 'STOCK_IN' && _selectedVendor == null
            ? (_supplier.text.trim().isNotEmpty ? _supplier.text.trim() : null)
            : null,
        purchasePriceMode:
            _type == 'STOCK_IN' && parsedUnitPrice != null ? _purchasePriceMode : null,
        note: _note.text.isNotEmpty ? _note.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(AppStrings.stockUpdated)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSizes.xl,
        right: AppSizes.xl,
        top: AppSizes.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: ShapeDecoration(
                  color: theme.colorScheme.outlineVariant,
                  shape: AppShapes.squircle(2),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            Text(widget.product.name, style: theme.textTheme.titleMedium),
            Text(
              'Current stock: ${_formatQty(widget.product.stockQuantity)} ${widget.product.unit}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            // Type selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'STOCK_IN',
                  label: Text(AppStrings.stockIn),
                  icon: Icon(Icons.add_rounded),
                ),
                ButtonSegment(
                  value: 'STOCK_OUT',
                  label: Text(AppStrings.stockOut),
                  icon: Icon(Icons.remove_rounded),
                ),
                ButtonSegment(
                  value: 'ADJUSTMENT',
                  label: Text(AppStrings.adjustment),
                  icon: Icon(Icons.swap_vert_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (v) {
                setState(() {
                  _type = v.first;
                  if (_type == 'STOCK_IN' && _unitPrice.text.trim().isEmpty) {
                    _unitPrice.text = widget.product.purchasePrice
                        .toStringAsFixed(2);
                  }
                  if (_type != 'STOCK_IN') {
                    _supplierFocusNode.unfocus();
                  }
                });

                if (_type == 'STOCK_IN') {
                  _loadSupplierOptions(
                    query: _supplier.text.trim().isEmpty
                        ? null
                        : _supplier.text.trim(),
                  );
                }
              },
            ),
            const SizedBox(height: AppSizes.lg),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    decoration: const InputDecoration(
                      labelText: AppStrings.quantity,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return AppStrings.fieldRequired;
                      }
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) {
                        return AppStrings.invalidNumber;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _unitPrice,
                    decoration: InputDecoration(
                      labelText: AppStrings.unitPrice,
                      prefixText: '${AppStrings.currencySymbol} ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (_type != 'STOCK_IN') {
                        if (v == null || v.isEmpty) {
                          return null;
                        }
                        return double.tryParse(v) == null
                            ? AppStrings.invalidNumber
                            : null;
                      }
                      if (v == null || v.isEmpty) {
                        return AppStrings.fieldRequired;
                      }
                      final n = double.tryParse(v);
                      if (n == null || n < 0) {
                        return AppStrings.invalidNumber;
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),

            if (_type == 'STOCK_IN') ...[
              // ── Vendor quick-select ───────────────────────────────────
              if (_isLoadingSuppliers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                  child: LinearProgressIndicator(),
                )
              else if (_vendors.isNotEmpty || _selectedVendor != null) ...[
                Text(
                  AppStrings.supplier,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSizes.xs),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.xs,
                  children: _vendors.map((v) {
                    final isSelected = _selectedVendor?.id == v.id;
                    return FilterChip(
                      label: Text(v.name),
                      selected: isSelected,
                      onSelected: (_) => isSelected ? _clearVendor() : _selectVendor(v),
                      avatar: Icon(
                        Icons.business_rounded,
                        size: 14,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onSecondaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSizes.sm),
              ],
              // ── Free-text supplier (when no vendor selected) ──────────
              if (_selectedVendor == null)
                RawAutocomplete<String>(
                  textEditingController: _supplier,
                  focusNode: _supplierFocusNode,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (_freeTextOptions.isEmpty) return const Iterable<String>.empty();
                    if (query.isEmpty) return _freeTextOptions;
                    return _freeTextOptions.where((o) => o.toLowerCase().contains(query));
                  },
                  onSelected: (option) {
                    _supplier
                      ..text = option
                      ..selection = TextSelection.collapsed(offset: option.length);
                  },
                  fieldViewBuilder: (context, ctrl, focusNode, _) => TextFormField(
                    controller: ctrl,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: AppStrings.supplier,
                      helperText: _freeTextOptions.isEmpty
                          ? AppStrings.supplierHint
                          : AppStrings.supplierAutocompleteHint,
                      suffixIcon: _freeTextOptions.isNotEmpty
                          ? const Icon(Icons.history_rounded)
                          : null,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  optionsViewBuilder: (context, onSelected, options) {
                    final list = options.toList();
                    if (list.isEmpty) return const SizedBox.shrink();
                    final theme = Theme.of(context);
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: const EdgeInsets.only(top: AppSizes.xs),
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            minWidth: 200,
                            maxWidth: 360,
                          ),
                          decoration: ShapeDecoration(
                            color: theme.colorScheme.surface,
                            shape: AppShapes.squircle(
                              AppSizes.radiusMd,
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            shadows: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (context, i) => InkWell(
                              onTap: () => onSelected(list[i]),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.md,
                                  vertical: AppSizes.sm,
                                ),
                                child: Text(list[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: AppSizes.md),
              _PurchasePriceModeSection(
                currentPurchasePrice: widget.product.purchasePrice,
                currentStock: widget.product.stockQuantity,
                incomingUnitPrice: _parseDouble(_unitPrice.text),
                incomingQuantity: _parseDouble(_quantity.text),
                mode: _purchasePriceMode,
                onModeChanged: (value) {
                  setState(() => _purchasePriceMode = value);
                },
              ),
              const SizedBox(height: AppSizes.md),
            ],

            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: AppStrings.note),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.xxl),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppStrings.confirm),
            ),
            const SizedBox(height: AppSizes.xl),
          ],
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }
}

class _PurchasePriceModeSection extends StatelessWidget {
  const _PurchasePriceModeSection({
    required this.currentPurchasePrice,
    required this.currentStock,
    required this.incomingUnitPrice,
    required this.incomingQuantity,
    required this.mode,
    required this.onModeChanged,
  });

  final double currentPurchasePrice;
  final double currentStock;
  final double? incomingUnitPrice;
  final double? incomingQuantity;
  final String mode;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextPrice = _nextPurchasePrice();
    final hasPreview = nextPrice != null && incomingUnitPrice != null;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.24),
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.purchasePriceRule,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'WEIGHTED_AVERAGE',
                label: Text(AppStrings.weightedAverage),
              ),
              ButtonSegment(
                value: 'USE_LATEST',
                label: Text(AppStrings.useLatestPrice),
              ),
              ButtonSegment(
                value: 'KEEP_CURRENT',
                label: Text(AppStrings.keepCurrentPrice),
              ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (value) => onModeChanged(value.first),
          ),
          if (hasPreview) ...[
            const SizedBox(height: AppSizes.md),
            _PriceSummaryRow(
              label: AppStrings.currentPurchasePrice,
              value: _inr(currentPurchasePrice),
            ),
            _PriceSummaryRow(
              label: AppStrings.incomingPrice,
              value: _inr(incomingUnitPrice!),
            ),
            _PriceSummaryRow(
              label: AppStrings.nextPurchasePrice,
              value: _inr(nextPrice),
              isHighlight: true,
            ),
            const SizedBox(height: AppSizes.xs),
            Align(
              alignment: Alignment.centerRight,
              child: _PriceDeltaChip(
                percentDelta: _percentDelta(currentPurchasePrice, nextPrice),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double? _nextPurchasePrice() {
    if (incomingUnitPrice == null) {
      return null;
    }

    if (mode == 'KEEP_CURRENT') {
      return _roundCurrency(currentPurchasePrice);
    }

    if (mode == 'USE_LATEST') {
      return _roundCurrency(incomingUnitPrice!);
    }

    final qty = incomingQuantity;
    if (qty == null || qty <= 0) {
      return _roundCurrency(incomingUnitPrice!);
    }

    final nextStock = currentStock + qty;
    if (nextStock <= 0) {
      return _roundCurrency(incomingUnitPrice!);
    }

    final weightedAverage =
        (currentStock * currentPurchasePrice + qty * incomingUnitPrice!) /
        nextStock;
    return _roundCurrency(weightedAverage);
  }

  double _percentDelta(double before, double after) {
    if (before == 0) return 0;
    return ((after - before) / before) * 100;
  }

  double _roundCurrency(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  String _inr(double value) {
    return '${AppStrings.currencySymbol}${value.toStringAsFixed(2)}';
  }
}

class _PriceSummaryRow extends StatelessWidget {
  const _PriceSummaryRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              color: isHighlight ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceDeltaChip extends StatelessWidget {
  const _PriceDeltaChip({required this.percentDelta});

  final double percentDelta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncrease = percentDelta >= 0;
    final color = isIncrease
        ? const Color(0xFF1F8A5B)
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Text(
        '${isIncrease ? '+' : ''}${percentDelta.toStringAsFixed(2)}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
