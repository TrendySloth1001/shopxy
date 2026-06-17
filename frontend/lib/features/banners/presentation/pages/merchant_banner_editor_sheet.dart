import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/banners/data/datasources/merchant_banners_remote_data_source.dart';
import 'package:shopxy/features/banners/data/models/banner_product.dart';
import 'package:shopxy/features/banners/presentation/providers/merchant_banners_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Modal sheet for creating or editing a merchant banner. A banner is just
/// an image + placement + optional link + optional schedule, so the editor
/// is lean: upload the artwork, pick where it shows, and (optionally) when
/// and where it links.
class MerchantBannerEditorSheet extends StatefulWidget {
  const MerchantBannerEditorSheet({super.key, this.existing});
  final AdminBanner? existing;

  static Future<bool?> show(BuildContext context, {AdminBanner? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.95,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: MerchantBannerEditorSheet(existing: existing),
        ),
      ),
    );
  }

  @override
  State<MerchantBannerEditorSheet> createState() =>
      _MerchantBannerEditorSheetState();
}

class _MerchantBannerEditorSheetState extends State<MerchantBannerEditorSheet> {
  late BannerPlacement _placement;
  late final TextEditingController _linkUrl;
  late final TextEditingController _sortOrder;
  String? _imageUrl;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _isActive = true;
  bool _busy = false;

  final List<_BannerProductDraft> _products = [];
  bool _loadingProducts = false;
  bool _productsTouched = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _placement = e?.placement ?? BannerPlacement.hero;
    _linkUrl = TextEditingController(text: e?.linkUrl ?? '');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _imageUrl = e?.imageUrl;
    _startAt = e?.startAt;
    _endAt = e?.endAt;
    _isActive = e?.isActive ?? true;
    if (_isEdit) _loadProducts();
  }

  @override
  void dispose() {
    _linkUrl.dispose();
    _sortOrder.dispose();
    for (final p in _products) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    final provider = context.read<MerchantBannersProvider>();
    try {
      final rows = await provider.listBannerProducts(widget.existing!.id);
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(rows.map(_BannerProductDraft.fromRow));
      });
    } catch (_) {
      // Non-fatal: the merchant can still edit the rest of the banner.
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    if (!_validateImageSize(file)) return;
    setState(() => _busy = true);
    final shop = context.read<ShopProvider>();
    final url = await shop.uploadImage(file);
    if (!mounted) return;
    setState(() => _busy = false);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shop.error ?? 'Image upload failed')),
      );
      return;
    }
    setState(() => _imageUrl = url);
  }

  /// Hard 5 MB ceiling — anything bigger usually means a raw camera
  /// capture, which both blows past the backend limit and stalls on
  /// slow connections.
  bool _validateImageSize(File file) {
    const maxBytes = 5 * 1024 * 1024;
    if (file.lengthSync() > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image is larger than 5 MB. Pick a smaller image or crop tighter.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startAt : _endAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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

  Future<void> _save() async {
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An image is required')),
      );
      return;
    }
    setState(() => _busy = true);
    final provider = context.read<MerchantBannersProvider>();
    final body = <String, dynamic>{
      'placement': _placement.wire,
      'imageUrl': _imageUrl,
      if (_linkUrl.text.trim().isNotEmpty) 'linkUrl': _linkUrl.text.trim(),
      'sortOrder': int.tryParse(_sortOrder.text) ?? 0,
      if (_startAt != null) 'startAt': _startAt!.toUtc().toIso8601String(),
      if (_endAt != null) 'endAt': _endAt!.toUtc().toIso8601String(),
      'isActive': _isActive,
    };
    final result = _isEdit
        ? await provider.update(widget.existing!.id, body)
        : await provider.create(body);
    if (!mounted) return;
    if (result == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Save failed')),
      );
      return;
    }
    // Persist the curated product list only for existing banners — the
    // product section is hidden until the banner has an id. Skip the PUT
    // entirely if the merchant never touched it.
    if (_isEdit && _productsTouched) {
      final items = _products
          .asMap()
          .entries
          .map((e) => BannerProductInput(
                productId: e.value.product.id,
                discountType: e.value.discountType,
                discountValue: e.value.discountValueOrZero,
                position: e.key,
              ))
          .toList();
      try {
        await provider.replaceBannerProducts(result.id, items);
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Banner saved, but products failed: $e')),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (_, _) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: const _BannerProductPickerSheet(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (_products.any((p) => p.product.id == picked.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already pinned to this banner')),
      );
      return;
    }
    setState(() {
      _productsTouched = true;
      _products.add(_BannerProductDraft.fromProduct(picked));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                _isEdit ? 'Edit banner' : 'New banner',
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
              _imageRow(),
              const SizedBox(height: AppSizes.md),
              DropdownButtonFormField<BannerPlacement>(
                initialValue: _placement,
                decoration: const InputDecoration(labelText: 'Placement'),
                items: BannerPlacement.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (v) => setState(() => _placement = v ?? _placement),
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _linkUrl,
                      decoration: const InputDecoration(
                        labelText: 'Link',
                        helperText: 'category:slug | product:id | url:https://…',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _sortOrder,
                      decoration: const InputDecoration(labelText: 'Sort'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              _scheduleRow(),
              const SizedBox(height: AppSizes.lg),
              SwitchListTile.adaptive(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('When off, hidden regardless of schedule'),
              ),
              const SizedBox(height: AppSizes.lg),
              _productsSection(),
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : (_isEdit ? 'Save changes' : 'Create banner')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageRow() {
    return Row(
      children: [
        Container(
          width: 90,
          height: 60,
          decoration: ShapeDecoration(
            color: AppColors.heroPanel,
            shape: AppShapes.squircle(AppSizes.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: _imageUrl == null
              ? const Icon(Icons.image_outlined, color: AppColors.muted)
              : Image.network(
                  resolveImageUrl(_imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.upload_outlined),
            label: Text(_imageUrl == null ? 'Upload image *' : 'Replace image'),
            onPressed: _busy ? null : _pickImage,
          ),
        ),
      ],
    );
  }

  Widget _scheduleRow() {
    final df = DateFormat.yMMMd().add_jm();
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: 'Starts',
            value: _startAt,
            formatter: df,
            onTap: () => _pickDate(isStart: true),
            onClear: _startAt == null
                ? null
                : () => setState(() => _startAt = null),
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: _DateField(
            label: 'Ends',
            value: _endAt,
            formatter: df,
            onTap: () => _pickDate(isStart: false),
            onClear: _endAt == null ? null : () => setState(() => _endAt = null),
          ),
        ),
      ],
    );
  }

  Widget _productsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (_isEdit)
              TextButton.icon(
                onPressed: _busy ? null : _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        if (!_isEdit)
          const _Hint(
            text: 'Save the banner first to add products.',
          )
        else if (_loadingProducts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_products.isEmpty)
          const _Hint(
            text: 'Tap “Add” to pin products with an optional discount.',
          )
        else
          ..._products.asMap().entries.map(
                (e) => _ProductRow(
                  key: ValueKey(e.value.product.id),
                  draft: e.value,
                  onChanged: () => setState(() => _productsTouched = true),
                  onRemove: () => setState(() {
                    _productsTouched = true;
                    _products.removeAt(e.key).dispose();
                  }),
                ),
              ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Container(
        width: AppSizes.handleWidth,
        height: AppSizes.handleHeight,
        decoration: BoxDecoration(
          color: AppColors.disabled,
          borderRadius: BorderRadius.circular(AppSizes.radiusXs),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: AppSizes.iconMd),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today_outlined,
                  size: AppSizes.iconMd),
        ),
        child: Text(
          value == null ? 'Not set' : formatter.format(value!),
          style: TextStyle(
            color: value == null ? AppColors.muted : AppColors.black,
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.muted)),
    );
  }
}

/// Mutable editor state for one pinned product. Wraps a slim product
/// summary, the chosen discount, and its editable value controller.
class _BannerProductDraft {
  _BannerProductDraft({
    required this.product,
    required this.discountType,
    required double discountValue,
  }) : valueController = TextEditingController(
          text: discountValue == 0
              ? ''
              : _trimDecimal(discountValue),
        );

  factory _BannerProductDraft.fromRow(BannerProductRow row) =>
      _BannerProductDraft(
        product: row.product,
        discountType: row.discountType,
        discountValue: row.discountValue,
      );

  factory _BannerProductDraft.fromProduct(Product p) {
    String? img;
    if (p.images.isNotEmpty) {
      final sorted = [...p.images]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      img = sorted.first.url;
    }
    return _BannerProductDraft(
      product: BannerProductSummary(
        id: p.id,
        name: p.name,
        sku: p.sku,
        mrp: p.mrp,
        sellingPrice: p.sellingPrice,
        imageUrl: img,
      ),
      discountType: BannerDiscountType.percent,
      discountValue: 0,
    );
  }

  final BannerProductSummary product;
  BannerDiscountType discountType;
  final TextEditingController valueController;

  double get discountValueOrZero =>
      double.tryParse(valueController.text.trim()) ?? 0;

  /// Live preview of the sale price as the merchant types — mirrors the
  /// backend's salePrice = sellingPrice - perUnitDiscount.
  double get salePrice {
    final base = product.sellingPrice;
    final v = discountValueOrZero;
    final off = discountType == BannerDiscountType.percent
        ? base * (v.clamp(0, 90) / 100)
        : v;
    final result = base - off;
    return result < 0 ? 0 : result;
  }

  void dispose() => valueController.dispose();

  static String _trimDecimal(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _BannerProductDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'en_IN');
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.avatarSm,
                height: AppSizes.avatarSm,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                child: draft.product.imageUrl == null
                    ? const Icon(Icons.image_outlined, color: AppColors.muted)
                    : Image.network(
                        resolveImageUrl(draft.product.imageUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      draft.product.sku,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: AppSizes.iconMd),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              SegmentedButton<BannerDiscountType>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: BannerDiscountType.values
                    .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                    .toList(),
                selected: {draft.discountType},
                onSelectionChanged: (sel) {
                  draft.discountType = sel.first;
                  onChanged();
                },
              ),
              const SizedBox(width: AppSizes.sm),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: draft.valueController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '0',
                    prefixText: draft.discountType == BannerDiscountType.amount
                        ? '₹'
                        : null,
                    suffixText: draft.discountType == BannerDiscountType.percent
                        ? '%'
                        : null,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const Spacer(),
              Text(
                currency.format(draft.salePrice),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Searches the merchant's own catalogue (`ProductsRemoteDataSource`) and
/// returns the tapped [Product] to the editor.
class _BannerProductPickerSheet extends StatefulWidget {
  const _BannerProductPickerSheet();
  @override
  State<_BannerProductPickerSheet> createState() =>
      _BannerProductPickerSheetState();
}

class _BannerProductPickerSheetState extends State<_BannerProductPickerSheet> {
  final _controller = TextEditingController();
  List<Product> _results = [];
  Timer? _debounce;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(AppDurations.searchDebounce, () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final ds = context.read<ProductsRemoteDataSource>();
        final res = await ds.getProducts(search: value.trim(), limit: 20);
        if (!mounted) return;
        setState(() => _results = res.products);
      } catch (_) {
        if (mounted) setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Search product name or SKU',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _onChanged,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results.isEmpty
              ? const Center(
                  child: Text(
                    'Type 2+ characters to search',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.sm,
                    AppSizes.lg,
                    AppSizes.huge,
                  ),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSizes.sm),
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    final img = p.images.isEmpty
                        ? null
                        : ([...p.images]
                              ..sort((a, b) =>
                                  a.sortOrder.compareTo(b.sortOrder)))
                            .first
                            .url;
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(p),
                      borderRadius:
                          AppShapes.squircleRadius(AppSizes.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(AppSizes.sm),
                        decoration: ShapeDecoration(
                          color: AppColors.white,
                          shape: AppShapes.squircle(AppSizes.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: AppSizes.avatarSm,
                              height: AppSizes.avatarSm,
                              clipBehavior: Clip.antiAlias,
                              decoration: ShapeDecoration(
                                color: AppColors.heroPanel,
                                shape: AppShapes.squircle(AppSizes.radiusSm),
                              ),
                              child: img == null
                                  ? const Icon(Icons.image_outlined,
                                      color: AppColors.muted)
                                  : Image.network(
                                      resolveImageUrl(img),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined),
                                    ),
                            ),
                            const SizedBox(width: AppSizes.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                    p.sku,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
