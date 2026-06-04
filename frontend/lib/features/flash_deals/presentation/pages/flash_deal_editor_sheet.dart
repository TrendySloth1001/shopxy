import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/flash_deals/data/models/flash_deal.dart';
import 'package:shopxy/features/flash_deals/presentation/providers/flash_deals_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Bottom-sheet modal for creating or editing a flash deal. On create
/// the merchant first picks a product, then sets price + stock +
/// window; on edit the product is fixed (the backend keys the sale by
/// product), so we only show the editable fields.
class FlashDealEditorSheet extends StatefulWidget {
  const FlashDealEditorSheet({super.key, this.existing});
  final FlashDeal? existing;

  static Future<bool?> show(BuildContext context, {FlashDeal? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, _) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: FlashDealEditorSheet(existing: existing),
        ),
      ),
    );
  }

  @override
  State<FlashDealEditorSheet> createState() => _FlashDealEditorSheetState();
}

class _FlashDealEditorSheetState extends State<FlashDealEditorSheet> {
  Product? _picked;
  late final TextEditingController _flashPrice;
  late final TextEditingController _stockLimit;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _flashPrice = TextEditingController(
      text: e == null ? '' : e.flashPrice.toStringAsFixed(2),
    );
    _stockLimit = TextEditingController(text: e == null ? '50' : '${e.stockLimit}');
    _startAt = e?.startAt ?? DateTime.now();
    _endAt = e?.endAt ?? DateTime.now().add(const Duration(hours: 4));
    if (e?.product != null) {
      // Synthesise a minimal Product so the preview card works in edit mode
      // — we don't have the full entity from the deal response, but the
      // preview only needs name, mrp, sellingPrice, image.
      _picked = Product(
        id: e!.product!.id,
        name: e.product!.name,
        sku: e.product!.sku,
        mrp: e.product!.mrp,
        sellingPrice: e.product!.sellingPrice,
        purchasePrice: 0,
        taxPercent: 0,
        stockQuantity: 0,
        lowStockThreshold: 0,
        unit: 'PCS',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  void dispose() {
    _flashPrice.dispose();
    _stockLimit.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final ds = context.read<ProductsRemoteDataSource>();
    final result = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductPickerSheet(ds: ds),
    );
    if (result != null) {
      setState(() {
        _picked = result;
        // Auto-suggest 80% of selling price as a starting flash price
        // — most merchants accept this as a reasonable opening offer.
        if (_flashPrice.text.isEmpty) {
          _flashPrice.text = (result.sellingPrice * 0.8).toStringAsFixed(2);
        }
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startAt : _endAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final t = time ?? const TimeOfDay(hour: 0, minute: 0);
    final combined = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _endAt = combined;
      }
    });
  }

  double? get _flashPriceNum {
    final v = double.tryParse(_flashPrice.text);
    if (v == null || v < 0) return null;
    return v;
  }

  int? get _stockNum {
    final v = int.tryParse(_stockLimit.text);
    if (v == null || v <= 0) return null;
    return v;
  }

  int? get _discountPct {
    if (_picked == null || _flashPriceNum == null) return null;
    final mrp = _picked!.mrp;
    if (mrp <= 0) return null;
    return (((mrp - _flashPriceNum!) / mrp) * 100).round();
  }

  /// Inline error shown directly under the flash-price input. Returns
  /// non-null only once both the price and the picked product are
  /// available, so empty / not-yet-picked states don't read as errors.
  String? get _flashPriceError {
    if (_flashPriceNum == null) return null;
    final mrp = _picked?.mrp;
    if (mrp == null || mrp <= 0) return null;
    if (_flashPriceNum! >= mrp) {
      return 'Must be lower than MRP (₹${mrp.toStringAsFixed(2)})';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_isEdit && _picked == null) {
      setState(() => _error = 'Pick a product first');
      return;
    }
    if (_flashPriceNum == null) {
      setState(() => _error = 'Enter a valid flash price');
      return;
    }
    // A flash price at or above MRP isn't really a flash deal — it'd
    // show as a 0% (or negative) discount on the customer card. Reject
    // up front rather than letting the backend surface a confusing
    // 422 after the merchant has filled the whole form.
    if (_picked != null && _picked!.mrp > 0 && _flashPriceNum! >= _picked!.mrp) {
      setState(() => _error = 'Flash price must be below MRP');
      return;
    }
    if (_stockNum == null) {
      setState(() => _error = 'Enter a positive stock limit');
      return;
    }
    if (_startAt == null || _endAt == null || !_endAt!.isAfter(_startAt!)) {
      setState(() => _error = 'End time must be after start time');
      return;
    }

    setState(() => _busy = true);
    final provider = context.read<FlashDealsProvider>();
    final result = _isEdit
        ? await provider.update(widget.existing!.id, {
            'flashPrice': _flashPriceNum,
            'stockLimit': _stockNum,
            'startAt': _startAt!.toUtc().toIso8601String(),
            'endAt': _endAt!.toUtc().toIso8601String(),
          })
        : await provider.create(
            productId: _picked!.id,
            flashPrice: _flashPriceNum!,
            stockLimit: _stockNum!,
            startAt: _startAt!,
            endAt: _endAt!,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = provider.error ?? 'Save failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSizes.sm),
        Container(
          width: AppSizes.xxxl,
          height: AppSizes.xs,
          decoration: BoxDecoration(
            color: AppColors.disabled,
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                _isEdit ? 'Edit flash deal' : 'New flash deal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.lg,
              AppSizes.huge,
            ),
            children: [
              _PreviewCard(
                product: _picked,
                flashPrice: _flashPriceNum ?? 0,
                discountPct: _discountPct ?? 0,
              ),
              const SizedBox(height: AppSizes.lg),
              if (!_isEdit) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.search),
                  label: Text(_picked == null ? 'Pick a product' : 'Change product'),
                  onPressed: _busy ? null : _pickProduct,
                ),
                if (_picked != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.sm),
                    child: Text(
                      '${_picked!.name}  ·  SKU ${_picked!.sku}  ·  MRP ₹${_picked!.mrp.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                const SizedBox(height: AppSizes.md),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _flashPrice,
                      decoration: InputDecoration(
                        labelText: 'Flash price (₹)',
                        helperText:
                            _flashPriceError == null && _discountPct != null
                                ? '$_discountPct% off MRP'
                                : null,
                        errorText: _flashPriceError,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextField(
                      controller: _stockLimit,
                      decoration: const InputDecoration(
                        labelText: 'Stock cap',
                        helperText: 'Hard limit — sells out + stops here',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Starts',
                      value: _startAt,
                      formatter: df,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: _DateField(
                      label: 'Ends',
                      value: _endAt,
                      formatter: df,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSizes.md),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                      ),
                ),
              ],
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy ? 'Saving…' : (_isEdit ? 'Save changes' : 'Create flash deal'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: AppSizes.iconSm),
        ),
        child: Text(
          value == null ? 'Not set' : formatter.format(value!),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: value == null ? AppColors.muted : AppColors.black,
              ),
        ),
      ),
    );
  }
}

/// Mini search + list pattern reused inside the editor sheet so the
/// merchant doesn't navigate away from their unsaved form.
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.ds});
  final ProductsRemoteDataSource ds;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _q = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      // listProducts returns the merchant's own active catalog.
      final page = await widget.ds.getProducts(
        page: 1,
        limit: 30,
        search: q,
      );
      if (!mounted) return;
      setState(() {
        _results = page.products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.canvas,
        shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      ),
      padding: EdgeInsets.only(
        top: AppSizes.md,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.xxxl,
            height: AppSizes.xs,
            decoration: BoxDecoration(
              color: AppColors.disabled,
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: TextField(
              controller: _q,
              decoration: const InputDecoration(
                labelText: 'Search your catalog',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            height: 360,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: p.primaryImageUrl != null
                            ? ClipRRect(
                                borderRadius:
                                    AppShapes.squircleRadius(AppSizes.radiusSm),
                                child: Image.network(
                                  resolveImageUrl(p.primaryImageUrl!),
                                  width: AppSizes.productThumbSize,
                                  height: AppSizes.productThumbSize,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.inventory_2_outlined),
                                ),
                              )
                            : const Icon(Icons.inventory_2_outlined),
                        title: Text(p.name),
                        subtitle: Text(
                          'SKU ${p.sku} · ₹${p.sellingPrice.toStringAsFixed(2)}',
                        ),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Visual approximation of the customer-side flash card so the merchant
/// can sanity-check copy + discount + image before publishing.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.product,
    required this.flashPrice,
    required this.discountPct,
  });
  final Product? product;
  final double flashPrice;
  final int discountPct;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product?.primaryImageUrl;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.flashDealSoft, AppColors.flashDealSoftAlt],
        ),
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(AppSizes.radiusMd),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (imageUrl != null)
                  Positioned.fill(
                    child: Image.network(
                      resolveImageUrl(imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined, color: AppColors.muted),
                    ),
                  )
                else
                  const Center(
                    child: Icon(Icons.image_outlined, color: AppColors.muted),
                  ),
                if (discountPct > 0)
                  Positioned(
                    top: AppSizes.xs,
                    left: AppSizes.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.xs,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.flashDeal,
                        borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                      ),
                      child: Text(
                        '-$discountPct%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AppColors.flashDeal, size: AppSizes.iconSm),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                      'Flash deal preview',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.flashDeal,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  product?.name ?? 'Pick a product to preview',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSizes.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${flashPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.flashDeal,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (product != null) ...[
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        '₹${product!.mrp.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                      ),
                    ],
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
