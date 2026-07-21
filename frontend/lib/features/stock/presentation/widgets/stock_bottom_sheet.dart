import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/stock/presentation/providers/stock_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

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
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _supplier = TextEditingController();
  final _supplierFocusNode = FocusNode();
  final _note = TextEditingController();

  // Vendor selection (STOCK_IN) — structured vendors from /stock/suppliers
  List<_SV> _vendors = const [];
  _SV? _selectedVendor;
  List<String> _freeTextOptions = const [];
  Timer? _supplierDebounce;
  bool _isLoadingSuppliers = false;
  String _lastSupplierQuery = '';

  // Party selection (STOCK_OUT) — customer the goods go to.
  final _partyQuery = TextEditingController();
  Party? _selectedParty;
  List<Party> _partyResults = const [];
  Timer? _partyDebounce;
  bool _isSearchingParties = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _seedUnitPrice();
    if (_type == 'STOCK_IN') {
      _loadSupplierOptions();
    } else {
      _searchParties('');
    }
    _unitPrice.addListener(_refreshForm);
    _quantity.addListener(_refreshForm);
    _supplier.addListener(_onSupplierInputChanged);
    _partyQuery.addListener(_onPartyQueryChanged);
  }

  void _seedUnitPrice() {
    if (_unitPrice.text.trim().isNotEmpty) return;
    _unitPrice.text =
        (_type == 'STOCK_IN'
                ? widget.product.purchasePrice
                : widget.product.sellingPrice)
            .toStringAsFixed(2);
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitPrice.dispose();
    _supplier.removeListener(_onSupplierInputChanged);
    _supplier.dispose();
    _supplierFocusNode.dispose();
    _supplierDebounce?.cancel();
    _partyQuery.removeListener(_onPartyQueryChanged);
    _partyQuery.dispose();
    _partyDebounce?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _onPartyQueryChanged() {
    if (_type != 'STOCK_OUT') return;
    final query = _partyQuery.text.trim();
    if (_selectedParty != null && query != _selectedParty!.name) {
      _selectedParty = null;
    }
    _partyDebounce?.cancel();
    _partyDebounce = Timer(AppDurations.medium, () {
      _searchParties(query);
    });
  }

  Future<void> _searchParties(String query) async {
    setState(() => _isSearchingParties = true);
    try {
      final ds = context.read<PartiesRemoteDataSource>();
      final results = await ds.getParties(
        search: query.isEmpty ? null : query,
        limit: 8,
      );
      if (!mounted) return;
      setState(() {
        _partyResults = results;
        _isSearchingParties = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isSearchingParties = false);
    }
  }

  void _pickParty(Party party) {
    setState(() {
      _selectedParty = party;
      _partyQuery.text = party.name;
    });
  }

  void _clearParty() {
    setState(() {
      _selectedParty = null;
      _partyQuery.clear();
    });
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
    _supplierDebounce = Timer(AppDurations.medium, () {
      _loadSupplierOptions(query: query.isEmpty ? null : query);
    });
  }

  Future<void> _loadSupplierOptions({String? query}) async {
    if (_type != 'STOCK_IN') return;
    setState(() => _isLoadingSuppliers = true);
    // Capture data sources before any await — `context` must not be used
    // across an async gap (use_build_context_synchronously).
    final ds = context.read<StockRemoteDataSource>();
    final vendorsDs = context.read<VendorsRemoteDataSource>();
    try {
      var result = await ds.getSuppliers(
        query: query,
        productId: widget.product.id,
        limit: 12,
      );
      // If no product-specific vendors, fall back to all vendors that have
      // purchase history for this shop.
      if (result.vendors.isEmpty && result.freeTextSuppliers.isEmpty) {
        result = await ds.getSuppliers(query: query, limit: 12);
      }
      // Still nothing? `/stock/suppliers` only lists vendors with a prior
      // stock-in, so a freshly-added vendor never appears. Fall back to the
      // full vendor list so any saved vendor is selectable straight away.
      var vendors = result.vendors;
      if (vendors.isEmpty) {
        final all = await vendorsDs.getVendors(search: query, limit: 50);
        vendors = all
            .map((v) => SupplierVendor(id: v.id, name: v.name, phone: v.phone))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
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
    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);
    final parsedUnitPrice = _parseDouble(_unitPrice.text);
    final parsedQuantity = _parseDouble(_quantity.text);
    if (parsedQuantity == null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }
    try {
      final draftId = await context.read<StockProvider>().addStock(
        productId: widget.product.id,
        type: _type,
        quantity: parsedQuantity,
        unitPrice: parsedUnitPrice,
        vendorId: _type == 'STOCK_IN' ? _selectedVendor?.id : null,
        partyId: _type == 'STOCK_OUT' ? _selectedParty?.id : null,
        note: _note.text.isNotEmpty ? _note.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.stockSheetDraftCreated)));
        // Return the draft invoice id so the opener can offer an
        // inline "confirm this draft" affordance without leaving its
        // page. Callers that only need a saved/dismissed signal can
        // null-check the result.
        Navigator.pop(context, draftId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSizes.xl,
        right: AppSizes.xl,
        top: AppSizes.xl,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: AppSizes.handleWidth,
                  height: AppSizes.handleHeight,
                  decoration: ShapeDecoration(
                    color: AppColors.hairline,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),

              Center(
                child: LineIllustration(
                  kind: _type == 'STOCK_IN' ? LineArt.cable : LineArt.receipt,
                  size: AppSizes.massive + AppSizes.md,
                  accent: AppColors.brand,
                ),
              ),
              const SizedBox(height: AppSizes.sm),

              Text(
                widget.product.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                l10n.stockSheetCurrentStock(
                  _formatQty(widget.product.stockQuantity),
                  widget.product.unit,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xl),

              // Type selector — manual flow now produces a DRAFT invoice.
              // Damage / expired / shrinkage live on the Stock Adjustments
              // page; pure cash movements happen here.
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'STOCK_IN',
                    label: Text(l10n.stockSheetPurchase),
                    icon: const AppIcon(AppIcons.addRounded),
                  ),
                  ButtonSegment(
                    value: 'STOCK_OUT',
                    label: Text(l10n.stockSheetSale),
                    icon: const AppIcon(AppIcons.removeRounded),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (v) {
                  setState(() {
                    _type = v.first;
                    _unitPrice.text =
                        (_type == 'STOCK_IN'
                                ? widget.product.purchasePrice
                                : widget.product.sellingPrice)
                            .toStringAsFixed(2);
                    if (_type != 'STOCK_IN') _supplierFocusNode.unfocus();
                  });
                  if (_type == 'STOCK_IN') {
                    _loadSupplierOptions(
                      query: _supplier.text.trim().isEmpty
                          ? null
                          : _supplier.text.trim(),
                    );
                  } else {
                    _searchParties(_partyQuery.text.trim());
                  }
                },
              ),
              const SizedBox(height: AppSizes.lg),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      decoration: InputDecoration(
                        labelText: l10n.stockSheetQuantity,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l10n.stockSheetFieldRequired;
                        }
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) {
                          return l10n.stockSheetInvalidNumber;
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
                        labelText: l10n.stockSheetUnitPrice,
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
                              ? l10n.stockSheetInvalidNumber
                              : null;
                        }
                        if (v == null || v.isEmpty) {
                          return l10n.stockSheetFieldRequired;
                        }
                        final n = double.tryParse(v);
                        if (n == null || n < 0) {
                          return l10n.stockSheetInvalidNumber;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),

              if (_type == 'STOCK_OUT') ...[
                Text(
                  l10n.stockSheetCustomer,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                TextFormField(
                  controller: _partyQuery,
                  decoration: InputDecoration(
                    hintText: l10n.stockSheetSearchParties,
                    prefixIcon: const AppIcon(AppIcons.personSearchRounded),
                    suffixIcon: _selectedParty != null
                        ? IconButton(
                            icon: const AppIcon(AppIcons.closeRounded),
                            onPressed: _clearParty,
                            tooltip: l10n.stockSheetClear,
                          )
                        : _isSearchingParties
                        ? const Padding(
                            padding: EdgeInsets.all(AppSizes.md),
                            child: SizedBox(
                              width: AppSizes.lg,
                              height: AppSizes.lg,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                ),
                if (_selectedParty == null && _partyResults.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.xs),
                  Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.xs,
                    children: _partyResults.take(6).map((p) {
                      return ActionChip(
                        label: Text(p.name),
                        avatar: AppIcon(
                          p.name == 'Walk-in Customer'
                              ? AppIcons.directionsWalkRounded
                              : AppIcons.personRounded,
                          size: AppSizes.iconSm,
                        ),
                        onPressed: () => _pickParty(p),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSizes.md),
              ],

              if (_type == 'STOCK_IN') ...[
                // ── Vendor quick-select ───────────────────────────────────
                if (_isLoadingSuppliers)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                    child: LinearProgressIndicator(),
                  )
                else if (_vendors.isNotEmpty || _selectedVendor != null) ...[
                  Text(
                    l10n.stockSheetSupplier,
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
                        onSelected: (_) =>
                            isSelected ? _clearVendor() : _selectVendor(v),
                        avatar: AppIcon(
                          AppIcons.businessRounded,
                          size: AppSizes.iconSm,
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer
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
                      if (_freeTextOptions.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      if (query.isEmpty) return _freeTextOptions;
                      return _freeTextOptions.where(
                        (o) => o.toLowerCase().contains(query),
                      );
                    },
                    onSelected: (option) {
                      _supplier
                        ..text = option
                        ..selection = TextSelection.collapsed(
                          offset: option.length,
                        );
                    },
                    fieldViewBuilder: (context, ctrl, focusNode, _) =>
                        TextFormField(
                          controller: ctrl,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: l10n.stockSheetSupplier,
                            helperText: _freeTextOptions.isEmpty
                                ? l10n.stockSheetSupplierHint
                                : l10n.stockSheetSupplierAutocompleteHint,
                            suffixIcon: _freeTextOptions.isNotEmpty
                                ? const AppIcon(AppIcons.historyRounded)
                                : null,
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                    optionsViewBuilder: (context, onSelected, options) {
                      final list = options.toList();
                      if (list.isEmpty) return const SizedBox.shrink();
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
                              color: AppColors.surface,
                              shape: AppShapes.squircle(
                                AppSizes.radiusMd,
                                side: BorderSide(
                                  color: AppColors.hairline,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSizes.xs,
                              ),
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
              ],

              TextFormField(
                controller: _note,
                decoration: InputDecoration(labelText: l10n.stockSheetNote),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSizes.xxl),

              AppButton.primary(
                label: l10n.stockSheetConfirm,
                onPressed: _save,
                isLoading: _isSaving,
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
              const SizedBox(height: AppSizes.xl),
            ],
          ),
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
