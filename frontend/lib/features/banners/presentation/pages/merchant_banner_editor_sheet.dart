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
import 'package:shopxy/features/banners/domain/banner_link.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/banners/presentation/providers/merchant_banners_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

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
  late final TextEditingController _sortOrder;

  /// Where the banner sends a customer. Free text before — with helper copy
  /// documenting `category:slug | product:id | url:https://…`, all three of
  /// which the API rejected, while the two forms it did accept were dropped
  /// into the customer's search box verbatim. Nothing a merchant typed could
  /// ever work, so it's a structured picker now.
  BannerLinkKind? _linkKind;
  String? _linkValue;
  String? _linkLabel;
  late final TextEditingController _searchQuery;
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
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    final link = BannerLink.parse(e?.linkUrl);
    _linkKind = link?.kind;
    _linkValue = link?.value;
    _linkLabel = link?.value;
    _searchQuery = TextEditingController(
      text: link?.kind == BannerLinkKind.search ? link!.value : '',
    );
    _imageUrl = e?.imageUrl;
    _startAt = e?.startAt;
    _endAt = e?.endAt;
    _isActive = e?.isActive ?? true;
    if (_isEdit) _loadProducts();
  }

  @override
  void dispose() {
    _searchQuery.dispose();
    _sortOrder.dispose();
    for (final p in _products) {
      p.dispose();
    }
    super.dispose();
  }

  /// The canonical `kind:value` string, or null when the banner is
  /// decorative. Search reads its live text; the other kinds hold a value
  /// chosen from a picker, so it can't be mistyped.
  String? get _wireLink {
    final kind = _linkKind;
    if (kind == null) return null;
    final value = kind == BannerLinkKind.search
        ? _searchQuery.text.trim()
        : _linkValue;
    if (value == null || value.isEmpty) return null;
    return BannerLink(kind, value).toString();
  }

  Future<void> _pickLinkProduct() async {
    final picked = await _showProductPicker();
    if (picked == null || !mounted) return;
    setState(() {
      _linkValue = picked.id;
      _linkLabel = picked.name;
    });
  }

  Future<void> _pickLinkCategory() async {
    final categories = context
        .read<CategoriesProvider>()
        .categories
        .where((c) => (c.slug ?? '').isNotEmpty)
        .toList();
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categories are still loading.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            itemCount: categories.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(categories[i].name),
              subtitle: Text(categories[i].slug!),
              onTap: () => Navigator.of(context).pop(categories[i]),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _linkValue = picked.slug;
      _linkLabel = picked.name;
    });
  }

  void _selectLinkKind(BannerLinkKind? kind) {
    setState(() {
      _linkKind = kind;
      // A value only means something for the kind it was chosen under.
      _linkValue = null;
      _linkLabel = null;
      if (kind == BannerLinkKind.shop) {
        final shop = context.read<ShopProvider>().shop;
        _linkValue = shop?.slug;
        _linkLabel = shop?.name;
      }
    });
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
    final l10n = AppLocalizations.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      // Headroom over the 1600px `lg` variant the server generates: handing
      // sharp a source at exactly the target width means two resamples for no
      // gain, and anything under it ships a hero banner that gets upscaled on
      // every phone. Left uncompressed here — the server re-encodes to WebP.
      maxWidth: 2400,
    );
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
        SnackBar(content: Text(shop.error ?? l10n.bannersImageUploadFailed)),
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
        SnackBar(
          content: Text(AppLocalizations.of(context).bannersImageTooLarge),
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
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      t.hour,
      t.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _endAt = combined;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_imageUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bannersImageRequired)));
      return;
    }
    setState(() => _busy = true);
    final provider = context.read<MerchantBannersProvider>();
    final body = <String, dynamic>{
      'placement': _placement.wire,
      'imageUrl': _imageUrl,
      if (_wireLink != null) 'linkUrl': _wireLink,
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
        SnackBar(content: Text(provider.error ?? l10n.bannersSaveFailed)),
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
          .map(
            (e) => BannerProductInput(
              productId: e.value.product.id,
              discountType: e.value.discountType,
              discountValue: e.value.discountValueOrZero,
              position: e.key,
            ),
          )
          .toList();
      try {
        await provider.replaceBannerProducts(result.id, items);
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bannersProductsSaveFailed('$e'))),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
  }

  /// Shared by "pin a product" and "link to a product" so both search the
  /// same catalogue in the same sheet.
  Future<Product?> _showProductPicker() {
    return showModalBottomSheet<Product>(
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
  }

  Future<void> _addProduct() async {
    final l10n = AppLocalizations.of(context);
    final picked = await _showProductPicker();
    if (picked == null || !mounted) return;
    if (_products.any((p) => p.product.id == picked.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bannersAlreadyPinned)));
      return;
    }
    setState(() {
      _productsTouched = true;
      _products.add(_BannerProductDraft.fromProduct(picked));
    });
  }

  /// The control that names the destination, contextual to the chosen kind.
  /// Product and category are pickers rather than text so a merchant can't
  /// mistype an id the customer app would then fail to resolve.
  Widget _linkValueField() {
    switch (_linkKind!) {
      case BannerLinkKind.search:
        return TextField(
          controller: _searchQuery,
          decoration: const InputDecoration(
            labelText: 'Search for',
            helperText: 'Tapping the banner opens these results.',
          ),
          onChanged: (_) => setState(() {}),
        );
      case BannerLinkKind.shop:
        return _LinkTargetRow(
          label: _linkLabel ?? 'Your storefront',
          icon: AppIcons.storefrontOutlined,
          hint: 'Tapping the banner opens your shop page.',
        );
      case BannerLinkKind.product:
        return _LinkTargetRow(
          label: _linkLabel ?? 'Choose a product',
          icon: AppIcons.inventory2Outlined,
          chosen: _linkValue != null,
          onTap: _pickLinkProduct,
        );
      case BannerLinkKind.category:
        return _LinkTargetRow(
          label: _linkLabel ?? 'Choose a category',
          icon: AppIcons.categoryOutlined,
          chosen: _linkValue != null,
          onTap: _pickLinkCategory,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                _isEdit ? l10n.bannersEditBanner : l10n.bannersNewBanner,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const AppIcon(AppIcons.close),
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
                decoration: InputDecoration(labelText: l10n.bannersPlacement),
                items: BannerPlacement.values
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _placement = v ?? _placement),
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<BannerLinkKind?>(
                      initialValue: _linkKind,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.bannersLink),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('No link')),
                        DropdownMenuItem(
                          value: BannerLinkKind.product,
                          child: Text('A product'),
                        ),
                        DropdownMenuItem(
                          value: BannerLinkKind.category,
                          child: Text('A category'),
                        ),
                        DropdownMenuItem(
                          value: BannerLinkKind.shop,
                          child: Text('My shop'),
                        ),
                        DropdownMenuItem(
                          value: BannerLinkKind.search,
                          child: Text('A search'),
                        ),
                      ],
                      onChanged: _selectLinkKind,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _sortOrder,
                      decoration: InputDecoration(labelText: l10n.bannersSort),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              if (_linkKind != null) ...[
                const SizedBox(height: AppSizes.md),
                _linkValueField(),
              ],
              const SizedBox(height: AppSizes.lg),
              _scheduleRow(),
              const SizedBox(height: AppSizes.lg),
              SwitchListTile.adaptive(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.bannersActive),
                subtitle: Text(l10n.bannersActiveSubtitle),
              ),
              const SizedBox(height: AppSizes.lg),
              _productsSection(),
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? l10n.bannersSaving
                      : (_isEdit
                            ? l10n.bannersSaveChanges
                            : l10n.bannersCreateBanner),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageRow() {
    final l10n = AppLocalizations.of(context);
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
              ? AppIcon(AppIcons.imageOutlined, color: AppColors.muted)
              : Image.network(
                  resolveImageUrl(_imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const AppIcon(AppIcons.brokenImageOutlined),
                ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: OutlinedButton.icon(
            icon: const AppIcon(AppIcons.uploadOutlined),
            label: Text(
              _imageUrl == null
                  ? l10n.bannersUploadImage
                  : l10n.bannersReplaceImage,
            ),
            onPressed: _busy ? null : _pickImage,
          ),
        ),
      ],
    );
  }

  Widget _scheduleRow() {
    final l10n = AppLocalizations.of(context);
    final df = DateFormat.yMMMd().add_jm();
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: l10n.bannersStarts,
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
            label: l10n.bannersEnds,
            value: _endAt,
            formatter: df,
            onTap: () => _pickDate(isStart: false),
            onClear: _endAt == null
                ? null
                : () => setState(() => _endAt = null),
          ),
        ),
      ],
    );
  }

  Widget _productsSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.bannersProducts,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (_isEdit)
              TextButton.icon(
                onPressed: _busy ? null : _addProduct,
                icon: const AppIcon(AppIcons.add),
                label: Text(l10n.bannersAdd),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        if (!_isEdit)
          _Hint(text: l10n.bannersSaveFirstHint)
        else if (_loadingProducts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_products.isEmpty)
          _Hint(text: l10n.bannersAddProductsHint)
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
                  icon: const AppIcon(AppIcons.close, size: AppSizes.iconMd),
                  onPressed: onClear,
                )
              : const AppIcon(
                  AppIcons.calendarTodayOutlined,
                  size: AppSizes.iconMd,
                ),
        ),
        child: Text(
          value == null
              ? AppLocalizations.of(context).bannersNotSet
              : formatter.format(value!),
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
      child: Text(text, style: TextStyle(color: AppColors.muted)),
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
         text: discountValue == 0 ? '' : _trimDecimal(discountValue),
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
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline),
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
                    ? AppIcon(AppIcons.imageOutlined, color: AppColors.muted)
                    : Image.network(
                        resolveImageUrl(draft.product.imageUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const AppIcon(AppIcons.brokenImageOutlined),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const AppIcon(AppIcons.close, size: AppSizes.iconMd),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.bannersSearchProduct,
              prefixIcon: const AppIcon(AppIcons.search),
            ),
            onChanged: _onChanged,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    l10n.bannersSearchHint,
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
                        : ([...p.images]..sort(
                                (a, b) => a.sortOrder.compareTo(b.sortOrder),
                              ))
                              .first
                              .url;
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(p),
                      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(AppSizes.sm),
                        decoration: ShapeDecoration(
                          color: AppColors.surface,
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
                                  ? AppIcon(
                                      AppIcons.imageOutlined,
                                      color: AppColors.muted,
                                    )
                                  : Image.network(
                                      resolveImageUrl(img),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const AppIcon(
                                        AppIcons.brokenImageOutlined,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: AppSizes.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    p.sku,
                                    style: Theme.of(context).textTheme.bodySmall
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

/// Row showing the chosen link destination. Tappable when there's a picker
/// behind it; a plain statement of fact when the target is implied (my shop).
class _LinkTargetRow extends StatelessWidget {
  const _LinkTargetRow({
    required this.label,
    required this.icon,
    this.onTap,
    this.chosen = true,
    this.hint,
  });

  final String label;
  final AppIconData icon;
  final VoidCallback? onTap;
  final bool chosen;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(
            color: chosen ? AppColors.hairline : AppColors.brand,
          ),
        ),
      ),
      child: Row(
        children: [
          AppIcon(
            icon,
            size: AppSizes.iconMd,
            color: chosen ? AppColors.muted : AppColors.brand,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: chosen ? AppColors.black : AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    hint!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            AppIcon(
              AppIcons.chevronRightRounded,
              size: AppSizes.iconMd,
              color: AppColors.muted,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      child: row,
    );
  }
}
