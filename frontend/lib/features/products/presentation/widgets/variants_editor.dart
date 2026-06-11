import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Phase E — merchant variant editor. Lets the merchant declare one or
/// more axes (Colour, Size, …) and edit the per-variant grid. Stores
/// [axes] + [variants] in place; the parent reads them back on save.
///
/// v1 simplifies the experience: axes drive nothing automatically.
/// The merchant authors variants by hand and tags each with the right
/// attribute values. A future iteration can generate the cross-product
/// from axes.
class VariantsEditor extends StatefulWidget {
  const VariantsEditor({
    super.key,
    required this.axes,
    required this.variants,
    required this.defaultMrp,
    required this.defaultSellingPrice,
    required this.defaultPurchasePrice,
    required this.defaultSku,
    required this.onChange,
    required this.onUploadImage,
  });

  final List<VariantAxis> axes;
  final List<ProductVariant> variants;
  final double defaultMrp;
  final double defaultSellingPrice;
  final double defaultPurchasePrice;
  final String defaultSku;
  final VoidCallback onChange;
  /// Asynchronously upload an image and return its stored URL — the
  /// page injects its existing upload helper (camera/gallery picker +
  /// backend POST) so the variant card can reuse the same compressed
  /// upload path as the main product gallery. Returning null means
  /// the user cancelled the picker or the upload failed; the card
  /// just stays as-is.
  final Future<String?> Function(ImageSource source) onUploadImage;

  @override
  State<VariantsEditor> createState() => _VariantsEditorState();
}

class _VariantsEditorState extends State<VariantsEditor> {
  static const _maxAxes = 3;
  static const _maxVariantsPerProduct = 50;

  void _addAxis() {
    if (widget.axes.length >= _maxAxes) return;
    setState(() {
      widget.axes.add(const VariantAxis(name: '', values: <String>['']));
    });
    widget.onChange();
  }

  void _removeAxis(int i) {
    setState(() => widget.axes.removeAt(i));
    widget.onChange();
  }

  void _updateAxisName(int i, String name) {
    setState(() => widget.axes[i] = widget.axes[i].copyWith(name: name));
    widget.onChange();
  }

  void _addAxisValue(int i) {
    setState(() {
      widget.axes[i] = widget.axes[i]
          .copyWith(values: [...widget.axes[i].values, '']);
    });
    widget.onChange();
  }

  void _updateAxisValue(int i, int vi, String value) {
    final next = List<String>.from(widget.axes[i].values);
    next[vi] = value;
    setState(() => widget.axes[i] = widget.axes[i].copyWith(values: next));
    widget.onChange();
  }

  void _removeAxisValue(int i, int vi) {
    final next = List<String>.from(widget.axes[i].values)..removeAt(vi);
    setState(() => widget.axes[i] = widget.axes[i].copyWith(values: next));
    widget.onChange();
  }

  void _addVariant() {
    if (widget.variants.length >= _maxVariantsPerProduct) return;
    setState(() {
      widget.variants.add(ProductVariant(
        sku: '${widget.defaultSku}-${widget.variants.length + 1}',
        attributes: {for (final a in widget.axes) a.name: ''},
        mrp: widget.defaultMrp,
        sellingPrice: widget.defaultSellingPrice,
        purchasePrice: widget.defaultPurchasePrice,
      ));
    });
    widget.onChange();
  }

  void _removeVariant(int i) {
    setState(() => widget.variants.removeAt(i));
    widget.onChange();
  }

  void _updateVariant(int i, ProductVariant next) {
    setState(() => widget.variants[i] = next);
    widget.onChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Axes',
          style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800, color: AppColors.muted),
        ),
        const SizedBox(height: AppSizes.sm),
        for (var i = 0; i < widget.axes.length; i++)
          _AxisCard(
            axis: widget.axes[i],
            onName: (v) => _updateAxisName(i, v),
            onAddValue: () => _addAxisValue(i),
            onUpdateValue: (vi, v) => _updateAxisValue(i, vi, v),
            onRemoveValue: (vi) => _removeAxisValue(i, vi),
            onRemove: () => _removeAxis(i),
          ),
        if (widget.axes.length < _maxAxes)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add axis (e.g. Colour, Size)'),
              onPressed: _addAxis,
            ),
          ),
        const SizedBox(height: AppSizes.lg),
        Text(
          'Variants',
          style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800, color: AppColors.muted),
        ),
        const SizedBox(height: AppSizes.sm),
        for (var i = 0; i < widget.variants.length; i++)
          _VariantCard(
            axes: widget.axes,
            variant: widget.variants[i],
            onChange: (next) => _updateVariant(i, next),
            onRemove: () => _removeVariant(i),
            onUploadImage: widget.onUploadImage,
          ),
        if (widget.variants.length < _maxVariantsPerProduct)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add variant'),
              onPressed: _addVariant,
            ),
          ),
      ],
    );
  }
}

class _AxisCard extends StatelessWidget {
  const _AxisCard({
    required this.axis,
    required this.onName,
    required this.onAddValue,
    required this.onUpdateValue,
    required this.onRemoveValue,
    required this.onRemove,
  });
  final VariantAxis axis;
  final ValueChanged<String> onName;
  final VoidCallback onAddValue;
  final void Function(int, String) onUpdateValue;
  final ValueChanged<int> onRemoveValue;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: ShapeDecoration(
        shape: AppShapes.squircle(
          AppSizes.radiusSm,
          side: const BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: axis.name,
                  onChanged: onName,
                  decoration: const InputDecoration(
                    labelText: 'Axis name (e.g. Colour)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < axis.values.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: axis.values[i],
                      onChanged: (v) => onUpdateValue(i, v),
                      decoration: InputDecoration(
                        labelText: 'Value ${i + 1}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRemoveValue(i),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add value'),
              onPressed: onAddValue,
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.axes,
    required this.variant,
    required this.onChange,
    required this.onRemove,
    required this.onUploadImage,
  });
  final List<VariantAxis> axes;
  final ProductVariant variant;
  final ValueChanged<ProductVariant> onChange;
  final VoidCallback onRemove;
  final Future<String?> Function(ImageSource source) onUploadImage;

  Map<String, String> _patchAttr(String key, String value) =>
      {...variant.attributes, key: value};

  Future<void> _pickAndAdd(BuildContext context, ImageSource source) async {
    final url = await onUploadImage(source);
    if (url == null) return;
    onChange(variant.copyWith(imageUrls: [...variant.imageUrls, url]));
  }

  void _removeImage(int index) {
    final next = [...variant.imageUrls]..removeAt(index);
    onChange(variant.copyWith(imageUrls: next));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: ShapeDecoration(
        shape: AppShapes.squircle(
          AppSizes.radiusSm,
          side: const BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (variant.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm, vertical: 2),
                  decoration: ShapeDecoration(
                    color: AppColors.heroPanel,
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  child: Text(
                    'DEFAULT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: 0.6),
                  ),
                ),
              const Spacer(),
              if (!variant.isDefault)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          for (final a in axes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DropdownButtonFormField<String>(
                initialValue: variant.attributes[a.name]?.isEmpty == true
                    ? null
                    : variant.attributes[a.name],
                items: [
                  for (final v in a.values)
                    DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  onChange(
                      variant.copyWith(attributes: _patchAttr(a.name, v)));
                },
                decoration: InputDecoration(
                  labelText: a.name.isEmpty ? 'Axis' : a.name,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          TextFormField(
            initialValue: variant.sku,
            onChanged: (v) => onChange(variant.copyWith(sku: v)),
            decoration: const InputDecoration(
              labelText: 'SKU',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: variant.mrp.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => onChange(variant.copyWith(
                      mrp: double.tryParse(v) ?? variant.mrp)),
                  decoration: const InputDecoration(
                    labelText: 'MRP',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  initialValue: variant.sellingPrice.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => onChange(variant.copyWith(
                      sellingPrice:
                          double.tryParse(v) ?? variant.sellingPrice)),
                  decoration: const InputDecoration(
                    labelText: 'Selling',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  initialValue: variant.stockQuantity.toStringAsFixed(0),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => onChange(variant.copyWith(
                      stockQuantity:
                          double.tryParse(v) ?? variant.stockQuantity)),
                  decoration: const InputDecoration(
                    labelText: 'Stock',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _VariantImagesRow(
            urls: variant.imageUrls,
            onPickGallery: () =>
                _pickAndAdd(context, ImageSource.gallery),
            onPickCamera: () => _pickAndAdd(context, ImageSource.camera),
            onRemove: _removeImage,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Add images for this exact variant — what colour it looks '
            'like, how it fits. Customers picking this option will see '
            'these instead of the product-level gallery.',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Per-variant image strip + picker. Sits at the bottom of every
/// variant card. Thumbnails come straight from the upload pipeline
/// (already resized to 3 widths server-side) so the merchant gets
/// instant visual confirmation that the upload landed.
class _VariantImagesRow extends StatelessWidget {
  const _VariantImagesRow({
    required this.urls,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemove,
  });
  final List<String> urls;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (int i = 0; i < urls.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                    child: Image.network(
                      resolveImageUrl(urls[i]),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        decoration: ShapeDecoration(
                          color: AppColors.heroPanel,
                          shape: AppShapes.squircle(AppSizes.radiusSm),
                        ),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _AddVariantImageTile(
            onGallery: onPickGallery,
            onCamera: onPickCamera,
          ),
        ],
      ),
    );
  }
}

class _AddVariantImageTile extends StatelessWidget {
  const _AddVariantImageTile({
    required this.onGallery,
    required this.onCamera,
  });
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ImageSource>(
      tooltip: 'Add variant image',
      onSelected: (s) =>
          s == ImageSource.camera ? onCamera() : onGallery(),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: ImageSource.gallery,
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined, size: 18),
              SizedBox(width: 8),
              Text('From gallery'),
            ],
          ),
        ),
        PopupMenuItem(
          value: ImageSource.camera,
          child: Row(
            children: [
              Icon(Icons.photo_camera_outlined, size: 18),
              SizedBox(width: 8),
              Text('Take photo'),
            ],
          ),
        ),
      ],
      child: Container(
        width: 72,
        height: 72,
        decoration: ShapeDecoration(
          color: AppColors.surfaceTint,
          shape: AppShapes.squircle(
            AppSizes.radiusSm,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppColors.muted),
            const SizedBox(height: 2),
            Text(
              'Add',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
