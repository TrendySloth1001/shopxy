import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/custom_fields/data/datasources/custom_fields_remote_data_source.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_fields_form_section.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/data/models/product_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/domain/entities/product_draft.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/products/presentation/utils/product_ocr_parser.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/app_units.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';

class AddEditProductPage extends StatefulWidget {
  const AddEditProductPage({super.key, this.product, this.draft});
  final Product? product;
  final ProductDraft? draft;

  @override
  State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isScanning = false;
  // Heuristic unsaved-changes guard. Flipped true by any tracked text
  // controller listener or explicit mutation; reset to false right
  // before a successful Navigator.pop. Not exact — we only watch a
  // handful of representative fields to keep the wiring minimal.
  bool _dirty = false;

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _hsnCode;
  late final TextEditingController _mrp;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _taxPercent;
  late final TextEditingController _stockQuantity;
  late final TextEditingController _lowStockThreshold;

  String _selectedUnit = 'PCS';
  int? _selectedCategoryId;
  final List<String> _imageUrls = [];
  // For edit mode: maps url → existing image ID so we can call deleteImage
  final Map<String, int> _existingImageIdByUrl = {};
  final Set<int> _removedImageIds = {};
  final _imageUrlController = TextEditingController();

  bool _isUploading = false;

  // Custom field values, keyed by definition id. Loaded on init for
  // edit mode; written in one bulk call after product create/update
  // so the existing _save's success/error semantics still apply.
  final Map<int, String> _customFieldValues = {};

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final draft = p == null ? widget.draft : null;
    _name = TextEditingController(text: p?.name ?? draft?.name ?? '');
    _description = TextEditingController(
      text: p?.description ?? draft?.description ?? '',
    );
    _sku = TextEditingController(text: p?.sku ?? draft?.sku ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? draft?.barcode ?? '');
    _hsnCode = TextEditingController(text: p?.hsnCode ?? draft?.hsnCode ?? '');
    _mrp = TextEditingController(
      text: p?.mrp.toStringAsFixed(2) ?? _formatDouble(draft?.mrp),
    );
    _sellingPrice = TextEditingController(
      text:
          p?.sellingPrice.toStringAsFixed(2) ??
          _formatDouble(draft?.sellingPrice),
    );
    _purchasePrice = TextEditingController(
      text:
          p?.purchasePrice.toStringAsFixed(2) ??
          _formatDouble(draft?.purchasePrice),
    );
    _taxPercent = TextEditingController(
      text:
          p?.taxPercent.toString() ??
          _formatDouble(draft?.taxPercent, fallback: '0'),
    );
    _stockQuantity = TextEditingController(
      text:
          p?.stockQuantity.toString() ??
          _formatDouble(draft?.stockQuantity, fallback: '0'),
    );
    _lowStockThreshold = TextEditingController(
      text:
          p?.lowStockThreshold.toString() ??
          _formatDouble(draft?.lowStockThreshold, fallback: '10'),
    );
    _selectedUnit = p?.unit ?? draft?.unit ?? 'PCS';
    _selectedCategoryId = p?.categoryId ?? draft?.categoryId;

    if (p != null) {
      for (final img in p.images) {
        _imageUrls.add(img.url);
        _existingImageIdByUrl[img.url] = img.id;
      }
    }

    // Heuristic dirty-tracker — single listener shared across the
    // representative text fields. Avoids instrumenting every input.
    void markDirty() {
      if (!_dirty) _dirty = true;
    }
    _name.addListener(markDirty);
    _description.addListener(markDirty);
    _sellingPrice.addListener(markDirty);
    _stockQuantity.addListener(markDirty);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CategoriesProvider>().loadCategories();
      _loadCustomFieldValuesForEdit();
    });
  }

  Future<void> _loadCustomFieldValuesForEdit() async {
    if (widget.product == null) return;
    try {
      final values = await context
          .read<CustomFieldsRemoteDataSource>()
          .listValuesForProduct(widget.product!.id);
      if (!mounted) return;
      setState(() {
        for (final v in values) {
          _customFieldValues[v.definitionId] = v.value;
        }
      });
    } catch (_) {
      // Values are non-critical for editing the core product fields —
      // a transient fetch failure shouldn't block the form. The user
      // will see empty inputs and can refill or retry by reopening.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sku.dispose();
    _barcode.dispose();
    _hsnCode.dispose();
    _mrp.dispose();
    _sellingPrice.dispose();
    _purchasePrice.dispose();
    _taxPercent.dispose();
    _stockQuantity.dispose();
    _lowStockThreshold.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    // Capture before any awaits so we don't have to reach back through
    // context after async gaps.
    final provider = context.read<ProductsProvider>();
    final ds = context.read<ProductsRemoteDataSource>();
    final customFieldsDs = context.read<CustomFieldsRemoteDataSource>();
    try {
      int productId;
      if (isEditing) {
        productId = widget.product!.id;
        final data = ProductDto.toUpdateJson(
          name: _name.text,
          description: _description.text,
          sku: _sku.text,
          barcode: _barcode.text.isNotEmpty ? _barcode.text : null,
          hsnCode: _hsnCode.text.isNotEmpty ? _hsnCode.text : null,
          mrp: double.parse(_mrp.text),
          sellingPrice: double.parse(_sellingPrice.text),
          purchasePrice: double.parse(_purchasePrice.text),
          taxPercent: double.tryParse(_taxPercent.text),
          lowStockThreshold: double.tryParse(_lowStockThreshold.text),
          unit: _selectedUnit,
          categoryId: _selectedCategoryId,
        );
        await provider.updateProduct(productId, data);
        // Sync image deletions
        for (final imageId in _removedImageIds) {
          await ds.deleteImage(productId, imageId);
        }
        // Sync new image additions
        for (final url in _imageUrls) {
          if (!_existingImageIdByUrl.containsKey(url)) {
            await ds.addImage(productId, url);
          }
        }
      } else {
        final created = await provider.createProduct(
          name: _name.text,
          sku: _sku.text,
          mrp: double.parse(_mrp.text),
          sellingPrice: double.parse(_sellingPrice.text),
          purchasePrice: double.parse(_purchasePrice.text),
          description: _description.text,
          barcode: _barcode.text.isNotEmpty ? _barcode.text : null,
          hsnCode: _hsnCode.text.isNotEmpty ? _hsnCode.text : null,
          imageUrls: _imageUrls.isNotEmpty ? _imageUrls : null,
          taxPercent: double.tryParse(_taxPercent.text),
          stockQuantity: double.tryParse(_stockQuantity.text),
          lowStockThreshold: double.tryParse(_lowStockThreshold.text),
          unit: _selectedUnit,
          categoryId: _selectedCategoryId,
        );
        productId = created.id;
      }

      // One bulk call regardless of create/edit. Empty-string values
      // get treated as "clear" server-side, so retiring a previously
      // set custom field is just leaving its input blank.
      if (_customFieldValues.isNotEmpty) {
        await customFieldsDs.bulkSetValuesForProduct(
          productId,
          _customFieldValues.entries
              .map((e) => (definitionId: e.key, value: e.value))
              .toList(),
        );
      }

      _dirty = false;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    return null;
  }

  String? _priceValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final n = double.tryParse(value);
    if (n == null) return AppStrings.invalidNumber;
    if (n < 0) return AppStrings.priceMustBePositive;
    return null;
  }

  Future<void> _scanLabel() async {
    if (_isScanning) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
    );
    if (!mounted || image == null) return;
    setState(() => _isScanning = true);
    final recognizer = TextRecognizer();
    try {
      final input = InputImage.fromFilePath(image.path);
      final recognized = await recognizer.processImage(input);
      final draft = ProductOcrParser.fromText(recognized);
      if (!mounted) return;
      if (draft.hasAnyValue) {
        _applyDraft(draft, onlyEmpty: true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.ocrApplied)));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.ocrNoDetails)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.ocrFailed)));
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _applyDraft(ProductDraft draft, {required bool onlyEmpty}) {
    void applyText(TextEditingController controller, String? value) {
      if (value == null || value.trim().isEmpty) return;
      if (onlyEmpty && controller.text.trim().isNotEmpty) return;
      controller.text = value;
    }

    void applyNumber(TextEditingController controller, double? value) {
      if (value == null) return;
      if (onlyEmpty && controller.text.trim().isNotEmpty) return;
      controller.text = _formatDouble(value);
    }

    applyText(_name, draft.name);
    applyText(_description, draft.description);
    applyText(_sku, draft.sku);
    applyText(_barcode, draft.barcode);
    applyText(_hsnCode, draft.hsnCode);
    applyNumber(_mrp, draft.mrp);
    applyNumber(_sellingPrice, draft.sellingPrice);
    applyNumber(_purchasePrice, draft.purchasePrice);

    if (draft.taxPercent != null &&
        (!onlyEmpty || _taxPercent.text.trim().isEmpty)) {
      _taxPercent.text = _formatDouble(draft.taxPercent!);
    }
    if (draft.stockQuantity != null &&
        (!onlyEmpty || _stockQuantity.text.trim().isEmpty)) {
      _stockQuantity.text = _formatDouble(draft.stockQuantity!);
    }
    if (draft.lowStockThreshold != null &&
        (!onlyEmpty || _lowStockThreshold.text.trim().isEmpty)) {
      _lowStockThreshold.text = _formatDouble(draft.lowStockThreshold!);
    }
    if (draft.unit != null && (!onlyEmpty || _selectedUnit == 'PCS')) {
      setState(() => _selectedUnit = draft.unit!);
    }
    if (draft.categoryId != null &&
        (!onlyEmpty || _selectedCategoryId == null)) {
      setState(() => _selectedCategoryId = draft.categoryId);
    }
  }

  String _formatDouble(double? value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    if (_isUploading) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final url = await ds.uploadImage(File(picked.path));

      if (isEditing) {
        // In edit mode the image is persisted immediately so it
        // survives a mid-edit crash. We also need to remember the
        // returned ImageId — otherwise the save handler treats this
        // URL as "new" and posts it again, duplicating the row.
        final image = await ds.addImage(widget.product!.id, url);
        _existingImageIdByUrl[url] = image.id;
      }
      setState(() => _imageUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return;
    if (Uri.tryParse(url)?.hasScheme != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.invalidUrl)));
      return;
    }
    setState(() {
      _imageUrls.add(url);
      _imageUrlController.clear();
    });
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoriesProvider>().categories;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? AppStrings.editProduct : AppStrings.addProduct),
        actions: [
          IconButton(
            onPressed: _isScanning ? null : _scanLabel,
            tooltip: AppStrings.scanLabel,
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.document_scanner_outlined),
          ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            // ── Images section ────────────────────────────────────────
            AppSectionHeader(
              title: AppStrings.productImages.toUpperCase(),
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
            ),
            if (_imageUrls.isNotEmpty) ...[
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSizes.sm),
                  itemBuilder: (ctx, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        child: Image.network(
                          resolveImageUrl(_imageUrls[i]),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 96,
                            height: 96,
                            decoration: ShapeDecoration(
                              color: AppColors.white,
                              shape: AppShapes.squircle(
                                AppSizes.radiusMd,
                                side: BorderSide(color: AppColors.hairline, width: 1),
                              ),
                            ),
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            final url = _imageUrls[i];
                            final existingId = _existingImageIdByUrl[url];
                            if (existingId != null) _removedImageIds.add(existingId);
                            _imageUrls.removeAt(i);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
            ],
            // ── Pick from gallery / camera ────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () => _pickAndUploadImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text(AppStrings.pickFromGallery),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () => _pickAndUploadImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text(AppStrings.takePhoto),
                  ),
                ),
              ],
            ),
            if (_isUploading) ...[
              const SizedBox(height: AppSizes.sm),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSizes.sm),
            // ── URL fallback ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: AppStrings.addImageUrl,
                      hintText: AppStrings.imageUrlHint,
                    ),
                    keyboardType: TextInputType.url,
                    onFieldSubmitted: (_) => _addImageUrl(),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                IconButton.filled(
                  onPressed: _addImageUrl,
                  icon: const Icon(Icons.link_rounded),
                  tooltip: AppStrings.addImage,
                ),
              ],
            ),

            const SizedBox(height: AppSizes.xxl),

            // ── Basic info ────────────────────────────────────────────
            AppSectionHeader(
              title: AppStrings.sectionBasicInfo.toUpperCase(),
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
            ),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: AppStrings.productName,
              ),
              validator: _requiredValidator,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: AppStrings.description,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    decoration: const InputDecoration(
                      labelText: AppStrings.sku,
                    ),
                    validator: _requiredValidator,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _barcode,
                    decoration: const InputDecoration(
                      labelText: AppStrings.barcode,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hsnCode,
                    decoration: const InputDecoration(
                      labelText: AppStrings.hsnCode,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: () {
                    // Dropdown asserts when initialValue doesn't match
                    // any item — happens when the product references a
                    // category that's been deleted, or when categories
                    // haven't finished loading yet. Pin the displayed
                    // value to null in those cases; the underlying
                    // _selectedCategoryId stays unchanged until the
                    // user actively picks something else.
                    final hasMatch = _selectedCategoryId != null &&
                        categories.any((c) => c.id == _selectedCategoryId);
                    final dropdownValue = hasMatch ? _selectedCategoryId : null;
                    return DropdownButtonFormField<int?>(
                      initialValue: dropdownValue,
                      decoration: const InputDecoration(
                        labelText: AppStrings.category,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(AppStrings.none),
                        ),
                        ...categories.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedCategoryId = v),
                    );
                  }(),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.xxl),

            // ── Pricing ───────────────────────────────────────────────
            AppSectionHeader(
              title: AppStrings.sectionPricing.toUpperCase(),
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mrp,
                    decoration: InputDecoration(
                      labelText: AppStrings.mrp,
                      prefixText: '${AppStrings.currencySymbol} ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _sellingPrice,
                    decoration: InputDecoration(
                      labelText: AppStrings.sellingPrice,
                      prefixText: '${AppStrings.currencySymbol} ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePrice,
                    decoration: InputDecoration(
                      labelText: AppStrings.purchasePrice,
                      prefixText: '${AppStrings.currencySymbol} ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _taxPercent,
                    decoration: const InputDecoration(
                      labelText: AppStrings.taxPercent,
                      suffixText: '%',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.xxl),

            // ── Stock ────────────────────────────────────────────────
            AppSectionHeader(
              title: AppStrings.sectionStock.toUpperCase(),
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
            ),
            Row(
              children: [
                if (!isEditing)
                  Expanded(
                    child: TextFormField(
                      controller: _stockQuantity,
                      decoration: const InputDecoration(
                        labelText: AppStrings.stockQuantity,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                if (!isEditing) const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _lowStockThreshold,
                    decoration: const InputDecoration(
                      labelText: AppStrings.lowStockThreshold,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            DropdownButtonFormField<String>(
              // Defensive: if the product's stored unit isn't in the
              // known set (e.g. backend added new units, legacy data),
              // fall back to the first known unit so we don't trip
              // the Dropdown's "exactly one matching item" assertion.
              initialValue: AppUnits.all.contains(_selectedUnit)
                  ? _selectedUnit
                  : AppUnits.all.first,
              decoration: const InputDecoration(labelText: AppStrings.unit),
              items: AppUnits.all
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text('$u - ${AppUnits.label(u)}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedUnit = v);
              },
            ),

            const SizedBox(height: AppSizes.xl),
            // ── More about this product ───────────────────────────────
            // Shop-wide custom fields. Inline "+ Add field" lets the
            // user define a new field without leaving the form.
            AppSectionHeader(
              title: AppStrings.moreAboutThisProduct.toUpperCase(),
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
            ),
            CustomFieldsFormSection(
              values: _customFieldValues,
              onValueChanged: (id, value) =>
                  setState(() => _customFieldValues[id] = value),
            ),

            const SizedBox(height: AppSizes.huge),
          ],
        ),
      ),
      ),
    );
  }
}

