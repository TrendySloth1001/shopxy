import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:shopxy/features/custom_fields/data/datasources/custom_fields_remote_data_source.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_fields_form_section.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/data/models/hsn_dto.dart';
import 'package:shopxy/features/products/data/models/product_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/domain/entities/product_draft.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/products/presentation/utils/product_ocr_parser.dart';
import 'package:shopxy/features/products/presentation/widgets/content_blocks_editor.dart';
import 'package:shopxy/features/products/presentation/widgets/gst_rate_field.dart';
import 'package:shopxy/features/products/presentation/widgets/hsn_code_field.dart';
import 'package:shopxy/features/products/presentation/widgets/variants_editor.dart';
import 'package:shopxy/features/reviews/presentation/pages/product_reviews_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/app_units.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

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
  late final TextEditingController _brand;
  late final TextEditingController _mrp;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _taxPercent;
  late final TextEditingController _stockQuantity;
  late final TextEditingController _lowStockThreshold;

  /// What the HSN master last said, and which code it said it about. The pair
  /// is what separates "no rate on file for this code" from "haven't looked
  /// this one up yet" — only the former is worth warning about.
  HsnResolution? _hsnRate;
  String? _hsnCheckedFor;

  /// Whether the merchant has taken the rate off the code. Editing an existing
  /// product starts manual only when its stored rate was hand-typed — anything
  /// the master derived stays derived, so a re-save re-derives it.
  bool _taxManual = false;

  String _selectedUnit = 'PCS';
  String? _selectedCategoryId;
  final List<String> _imageUrls = [];
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  // V2 PDP descriptive fields. Mutable lists so the editor can add /
  // reorder / drop rows in place. Empty lists serialise as null (DTO
  // strips), so a merchant who doesn't touch these sections doesn't
  // ship empty arrays.
  final List<String> _highlights = [];
  final _highlightController = TextEditingController();
  final List<SpecGroup> _specs = [];
  final List<ProductOffer> _offers = [];
  // Phase C — A+ content blocks. Empty list serialises as null (DTO
  // strips), so a merchant who never opens the section ships no
  // payload. Block types are HERO/FEATURE/COMPARISON/GALLERY/TEXT;
  // see backend `contentBlockSchema` for the per-kind shape.
  final List<ContentBlock> _contentBlocks = [];
  // Phase E — variant axes + variants. The default variant is created
  // server-side on first product create, so [_variants] is empty until
  // an existing product is being edited.
  final List<VariantAxis> _variantAxes = [];
  final List<ProductVariant> _variants = [];
  // For edit mode: maps url → existing image ID so we can call deleteImage
  final Map<String, String> _existingImageIdByUrl = {};
  final Set<String> _removedImageIds = {};
  final _imageUrlController = TextEditingController();

  bool _isUploading = false;

  // Custom field values, keyed by definition id. Loaded on init for
  // edit mode; written in one bulk call after product create/update
  // so the existing _save's success/error semantics still apply.
  final Map<String, String> _customFieldValues = {};

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
    _brand = TextEditingController(text: p?.brand ?? '');
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
    // Open the GST field as an input only for a rate that was genuinely typed
    // by hand against a real code. A derived rate stays a readout, and a
    // product with no code at all has nothing to derive from yet.
    _taxManual = p != null &&
        p.taxSource == 'MANUAL' &&
        (p.hsnCode?.isNotEmpty ?? false);
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
      _tags.addAll(p.tags);
      _highlights.addAll(p.highlights);
      _specs.addAll(p.specs);
      _offers.addAll(p.offers);
      _contentBlocks.addAll(p.contentBlocks);
      _variantAxes.addAll(p.variantAxes);
      _variants.addAll(p.variants);
    }

    if (p != null) {
      for (final img in p.images) {
        _imageUrls.add(img.url);
        _existingImageIdByUrl[img.url] = img.id;
      }
    }

    // Heuristic dirty-tracker — single listener shared across the
    // representative text fields. Avoids instrumenting every input.
    // setState the first time so PopScope.canPop reflects the flipped
    // flag; subsequent edits skip the rebuild (already dirty).
    void markDirty() {
      if (_dirty) return;
      if (mounted) {
        setState(() => _dirty = true);
      } else {
        _dirty = true;
      }
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
    _brand.dispose();
    _mrp.dispose();
    _sellingPrice.dispose();
    _purchasePrice.dispose();
    _taxPercent.dispose();
    _stockQuantity.dispose();
    _lowStockThreshold.dispose();
    _imageUrlController.dispose();
    _tagController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  void _addTagFromInput() {
    final raw = _tagController.text.trim();
    if (raw.isEmpty) return;
    if (_tags.length >= 20) return;
    if (_tags.any((t) => t.toLowerCase() == raw.toLowerCase())) {
      _tagController.clear();
      return;
    }
    setState(() {
      _tags.add(raw);
      _dirty = true;
      _tagController.clear();
    });
  }

  void _addHighlight() {
    final raw = _highlightController.text.trim();
    if (raw.isEmpty) return;
    if (_highlights.length >= 8) return;
    // Backend caps each highlight at 140 chars; truncate so a long
    // entry doesn't turn into a 400 at save time.
    final entry = raw.length > 140 ? raw.substring(0, 140) : raw;
    setState(() {
      _highlights.add(entry);
      _dirty = true;
      _highlightController.clear();
    });
  }

  // Mirrors the per-kind required fields in backend `contentBlockSchema`.
  // Anything missing here would 400 the whole product save — so we filter
  // these out at submit time rather than let one stale block block the user.
  bool _isContentBlockShippable(ContentBlock b) {
    final d = b.data;
    switch (b.kind) {
      case 'HERO':
        return (d['imageUrl'] is String) &&
            (d['imageUrl'] as String).isNotEmpty &&
            (d['headline'] is String) &&
            (d['headline'] as String).isNotEmpty;
      case 'FEATURE':
        return (d['imageUrl'] is String) &&
            (d['imageUrl'] as String).isNotEmpty &&
            (d['title'] is String) &&
            (d['title'] as String).isNotEmpty &&
            (d['body'] is String) &&
            (d['body'] as String).isNotEmpty &&
            (d['side'] == 'LEFT' || d['side'] == 'RIGHT');
      case 'COMPARISON':
        final cols = d['columns'];
        final rows = d['rows'];
        return cols is List &&
            cols.length >= 2 &&
            rows is List &&
            rows.isNotEmpty;
      case 'GALLERY':
        final imgs = d['images'];
        return imgs is List && imgs.isNotEmpty;
      case 'TEXT':
        return (d['markdown'] is String) &&
            (d['markdown'] as String).isNotEmpty;
    }
    return false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    // Capture before any awaits so we don't have to reach back through
    // context after async gaps.
    final l10n = AppLocalizations.of(context);
    final provider = context.read<ProductsProvider>();
    final ds = context.read<ProductsRemoteDataSource>();
    final customFieldsDs = context.read<CustomFieldsRemoteDataSource>();
    final messenger = ScaffoldMessenger.of(context);
    // Soft guard: warn (don't block) if the typed SKU or barcode already
    // belongs to a different product. Backend's unique constraints still
    // own correctness; this just gives the user a chance to notice.
    final currentId = widget.product?.id;
    final skuText = _sku.text.trim();
    final barcodeText = _barcode.text.trim();
    Future<void> warnIfDuplicate(String code, String label) async {
      if (code.isEmpty) return;
      try {
        final existing = await ds.lookupByCode(code);
        if (existing != null && existing.id != currentId) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.productsDuplicateWarning(label))),
          );
        }
      } catch (_) {
        // Lookup failures are non-critical; never block the save on them.
      }
    }

    await warnIfDuplicate(skuText, 'SKU');
    await warnIfDuplicate(barcodeText, l10n.productsBarcodeLower);
    if (!mounted) return;
    // Drop content blocks whose per-kind required fields are missing.
    // Backend Zod will 400 on a malformed block even if the merchant
    // never touched it this session — e.g. a legacy COMPARISON block
    // saved before columns/rows became required.
    final droppedBlocks =
        _contentBlocks.length -
        _contentBlocks.where(_isContentBlockShippable).length;
    if (droppedBlocks > 0) {
      _contentBlocks.retainWhere(_isContentBlockShippable);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.productsDroppedBlocksPrefix} $droppedBlocks '
            '${droppedBlocks == 1 ? l10n.productsMalformedBlockSingular : l10n.productsMalformedBlockPlural}',
          ),
        ),
      );
    }
    try {
      String productId;
      if (isEditing) {
        productId = widget.product!.id;
        final data = ProductDto.toUpdateJson(
          name: _name.text,
          description: _description.text,
          sku: _sku.text,
          barcode: _barcode.text.isNotEmpty ? _barcode.text : null,
          hsnCode: _hsnCode.text.isNotEmpty ? _hsnCode.text : null,
          brand: _brand.text.trim().isNotEmpty ? _brand.text.trim() : null,
          mrp: double.parse(_mrp.text),
          sellingPrice: double.parse(_sellingPrice.text),
          purchasePrice: double.parse(_purchasePrice.text),
          taxPercent: double.tryParse(_taxPercent.text),
          lowStockThreshold: double.tryParse(_lowStockThreshold.text),
          unit: _selectedUnit,
          categoryId: _selectedCategoryId,
          tags: _tags,
          highlights: _highlights,
          // Send empty list explicitly when the merchant deleted all
          // rows so the backend can clear the JSONB column — DTO would
          // otherwise drop the key.
          specs: _specs,
          offers: _offers,
          contentBlocks: _contentBlocks,
          variantAxes: _variantAxes,
          // Send the full variants array — backend diffs by id and
          // soft-deletes (isActive=false) variants we drop.
          variants: _variants,
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
          brand: _brand.text.trim().isNotEmpty ? _brand.text.trim() : null,
          imageUrls: _imageUrls.isNotEmpty ? _imageUrls : null,
          taxPercent: double.tryParse(_taxPercent.text),
          stockQuantity: double.tryParse(_stockQuantity.text),
          lowStockThreshold: double.tryParse(_lowStockThreshold.text),
          unit: _selectedUnit,
          categoryId: _selectedCategoryId,
          tags: _tags.isNotEmpty ? _tags : null,
          highlights: _highlights.isNotEmpty ? _highlights : null,
          specs: _specs.isNotEmpty ? _specs : null,
          offers: _offers.isNotEmpty ? _offers : null,
          contentBlocks: _contentBlocks.isNotEmpty ? _contentBlocks : null,
          variantAxes: _variantAxes.isNotEmpty ? _variantAxes : null,
          variants: _variants.isNotEmpty ? _variants : null,
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
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _requiredValidator(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return l10n.productsFieldRequired;
    }
    return null;
  }

  String? _priceValidator(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return l10n.productsFieldRequired;
    }
    final n = double.tryParse(value);
    if (n == null) return l10n.productsInvalidNumber;
    if (n < 0) return l10n.productsPriceMustBePositive;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).productsOcrApplied),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).productsOcrNoDetails),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).productsOcrFailed)),
      );
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

  /// Pick + upload an image and return its stored URL. Used by the
  /// variants editor and the A+ content editor — they don't want to
  /// mutate the page's `_imageUrls` list, just attach the returned URL
  /// to their own row. Returns null on cancel / failure so the caller
  /// can no-op gracefully.
  Future<String?> _pickAndUploadVariantImage(ImageSource source) async {
    if (_isUploading) return null;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return null;
    final file = File(picked.path);
    const maxBytes = 5 * 1024 * 1024;
    if (file.lengthSync() > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).productsImageTooLarge),
        ),
      );
      return null;
    }
    setState(() => _isUploading = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      return await ds.uploadImage(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Cap on what the product gallery can carry — mirrors the backend
  /// `imageUrls.max(10)` validator on createProductSchema.
  static const int _maxGalleryImages = 10;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    if (_isUploading) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    await _uploadOne(File(picked.path));
  }

  /// Multi-pick path for the gallery — most merchants want to drop
  /// 5–8 product shots in a single tap, not babysit a one-at-a-time
  /// picker. iOS/Android both support multi-select natively. Files are
  /// uploaded sequentially so a slow connection produces visible
  /// progress, and one failure doesn't abort the rest of the batch.
  Future<void> _pickAndUploadMultiple() async {
    if (_isUploading) return;
    final picker = ImagePicker();
    final l10n = AppLocalizations.of(context);
    final remaining = _maxGalleryImages - _imageUrls.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.productsMaxImagesReached('$_maxGalleryImages')),
        ),
      );
      return;
    }
    final List<XFile> picked = await picker.pickMultiImage(
      // Match the single-pick path's compression so multi vs single
      // produce identically sized assets.
      maxWidth: 1200,
      imageQuality: 85,
      // Available on iOS — caps the system picker so the user can't
      // overshoot remaining capacity. Android falls back to client-
      // side trimming below.
      limit: remaining,
    );
    if (picked.isEmpty || !mounted) return;

    final batch = picked.take(remaining).toList();
    if (picked.length > batch.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.productsSelectedButOnlyFit('${picked.length}', '$remaining'),
          ),
        ),
      );
    }
    setState(() => _isUploading = true);
    int succeeded = 0;
    final failures = <String>[];
    for (final x in batch) {
      final file = File(x.path);
      if (file.lengthSync() > 5 * 1024 * 1024) {
        failures.add(l10n.productsFileTooLarge(x.name));
        continue;
      }
      final ok = await _uploadOne(file, externallyManaged: true);
      if (ok) {
        succeeded += 1;
      } else {
        failures.add(x.name);
      }
    }
    if (mounted) setState(() => _isUploading = false);
    if (succeeded > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.productsUploadedPrefix} $succeeded '
            '${succeeded == 1 ? l10n.productsImageSingular : l10n.productsImagePlural}',
          ),
        ),
      );
    }
    if (failures.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.productsSkippedPrefix} ${failures.length}: ${failures.take(3).join(', ')}'
            '${failures.length > 3 ? '…' : ''}',
          ),
        ),
      );
    }
  }

  /// Upload one file and attach its URL to the gallery. Shared by
  /// single, multi, and camera paths. Returns true on success.
  ///
  /// `externallyManaged` lets the multi-batch caller drive the
  /// `_isUploading` flag itself (it wraps the whole batch in one busy
  /// window); the single-shot callers leave it false and we toggle
  /// inline.
  Future<bool> _uploadOne(File file, {bool externallyManaged = false}) async {
    const maxBytes = 5 * 1024 * 1024;
    if (file.lengthSync() > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).productsImageTooLarge),
        ),
      );
      return false;
    }
    if (!externallyManaged) setState(() => _isUploading = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final url = await ds.uploadImage(file);

      if (isEditing) {
        // In edit mode the image is persisted immediately so it
        // survives a mid-edit crash. We also need to remember the
        // returned ImageId — otherwise the save handler treats this
        // URL as "new" and posts it again, duplicating the row.
        final image = await ds.addImage(widget.product!.id, url);
        _existingImageIdByUrl[url] = image.id;
      }
      setState(() => _imageUrls.add(url));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
      return false;
    } finally {
      if (!externallyManaged && mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return;
    if (Uri.tryParse(url)?.hasScheme != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).productsInvalidUrl),
        ),
      );
      return;
    }
    setState(() {
      _imageUrls.add(url);
      _imageUrlController.clear();
    });
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.productsDiscardTitle),
        content: Text(l10n.productsDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.productsKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.productsDiscard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  void _markDirty() => _dirty = true;

  /// The HSN → GST auto-fill.
  ///
  /// The rate is a consequence of the classification, so a resolved code
  /// overwrites whatever is in the GST field. It stays editable afterwards:
  /// the conditional slabs are real (apparel over ₹2,500 is 18%, not 5%) and
  /// the note under the field says when that applies.
  ///
  /// A code with no rate on file deliberately leaves the field untouched — a
  /// silent 0% is an under-charged invoice, which is the failure this whole
  /// feature exists to prevent.
  void _applyHsnRate(HsnResolution? hit) {
    if (!mounted) return;
    setState(() {
      _hsnRate = hit;
      _hsnCheckedFor = hit?.requestedCode ?? normalizeHsnCode(_hsnCode.text);
      // Never overwrite a rate the merchant has taken responsibility for.
      if (hit != null && !_taxManual) {
        _taxPercent.text = formatHsnRate(hit.gstRate);
        _dirty = true;
      }
    });
  }

  /// The resolved rate, but only while it still describes what's in the field.
  /// Guarding on the code stops a stale answer from explaining a number the
  /// merchant has since changed the code out from under.
  HsnResolution? get _rateForCurrentCode {
    final digits = normalizeHsnCode(_hsnCode.text);
    final rate = _hsnRate;
    return rate != null && rate.requestedCode == digits ? rate : null;
  }

  /// A code was entered and looked up, and the master had nothing. Distinct
  /// from "not looked up yet" — only the former is worth warning about.
  bool get _hsnUnknown {
    final digits = normalizeHsnCode(_hsnCode.text);
    return _hsnCheckedFor == digits && digits.length >= 4 && _hsnRate == null;
  }

  /// Push a focused, full-screen editor for one advanced section, then
  /// refresh the hub summaries when it returns. The [builder] receives a
  /// `refresh` callback so stateless editors (highlights, tags) can
  /// re-render the pushed page on add/remove. Stateful editors (specs,
  /// offers, A+ blocks, variants) manage their own rebuilds and can
  /// ignore it.
  Future<void> _openEditor({
    required String title,
    String? intro,
    required Widget Function(void Function() refresh) builder,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _EditorScaffold(title: title, intro: intro, builder: builder),
      ),
    );
    if (mounted) setState(() {}); // refresh the hub tile summaries
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoriesProvider>().categories;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(
          title: isEditing ? l10n.productsEditProduct : l10n.productsAddProduct,
          actions: [
            if (isEditing)
              IconButton(
                tooltip: l10n.productsReviews,
                icon: const AppIcon(AppIcons.reviewsOutlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductReviewsPage(
                      productId: widget.product!.id,
                      productName: widget.product!.name,
                      ratingAvg: widget.product!.ratingAvg,
                      ratingCount: widget.product!.ratingCount,
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: _isScanning ? null : _scanLabel,
              tooltip: l10n.productsScanLabel,
              icon: _isScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppIcon(AppIcons.documentScannerOutlined),
            ),
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.productsSave),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.lg + FloatingAppBar.contentTopInset(context),
              AppSizes.lg,
              AppSizes.lg,
            ),
            children: [
              // ── Photos ────────────────────────────────────────────────
              ..._photosSection(),

              const SizedBox(height: AppSizes.xl),

              // ── The essentials — everything required to publish ───────
              AppSectionHeader(
                title: l10n.productsSectionBasics,
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
              ),
              TextFormField(
                controller: _name,
                // Mirrors the backend zod limit (products.controller.ts
                // caps name at 200 chars) so the user hits the wall here
                // instead of on save.
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l10n.productsProductName,
                  hintText: l10n.productsNameHint,
                  counterText: '',
                ),
                validator: _requiredValidator,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: l10n.productsDescription,
                  hintText: l10n.productsDescriptionHint,
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _brand,
                decoration: InputDecoration(
                  labelText: l10n.productsBrand,
                  hintText: l10n.productsBrandHint,
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: AppSizes.lg),
              // ── Identity & stock ──────────────────────────────────────
              //
              // Ahead of Price on purpose: the HSN code decides the GST rate,
              // and the rate readout sits in the price block below. Asking for
              // the rate before the field that determines it read backwards.
              AppSectionHeader(
                title: l10n.productsSectionIdentityStock,
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
              ),
              TextFormField(
                controller: _sku,
                decoration: InputDecoration(
                  labelText: l10n.productsSku,
                  helperText: l10n.productsSkuHelper,
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _barcode,
                onChanged: (_) => _markDirty(),
                decoration: InputDecoration(
                  labelText: l10n.productsBarcode,
                  helperText: l10n.productsBarcodeHelper,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              // The classifier suggests codes from the product name and
              // re-resolves when the price crosses a threshold slab, so it has
              // to see both as they're typed. A ListenableBuilder on those two
              // controllers rebuilds this field alone — a page-level setState
              // per keystroke would rebuild the entire form.
              ListenableBuilder(
                listenable: Listenable.merge([_name, _sellingPrice]),
                builder: (context, _) => HsnCodeField(
                  controller: _hsnCode,
                  dataSource: context.read<ProductsRemoteDataSource>(),
                  onChanged: _markDirty,
                  onResolved: _applyHsnRate,
                  productName: _name.text,
                  price: double.tryParse(_sellingPrice.text.trim()),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              if (!isEditing)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockQuantity,
                        decoration: InputDecoration(
                          labelText: l10n.productsOpeningStock,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(child: _unitField()),
                  ],
                )
              else
                _unitField(),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _lowStockThreshold,
                onChanged: (_) => _markDirty(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.productsLowStockThreshold,
                  helperText: l10n.productsLowStockThresholdHelper,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _categoryField(categories),

              const SizedBox(height: AppSizes.lg),
              // ── Price ─────────────────────────────────────────────────
              AppSectionHeader(
                title: l10n.productsSectionPrice,
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sellingPrice,
                      decoration: InputDecoration(
                        labelText: l10n.productsSellingPriceLabel,
                        prefixText: '${AppStrings.currencySymbol} ',
                        helperText: l10n.productsSellingPriceHelper,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _priceValidator,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextFormField(
                      controller: _mrp,
                      decoration: InputDecoration(
                        labelText: l10n.productsMrp,
                        prefixText: '${AppStrings.currencySymbol} ',
                        helperText: l10n.productsMrpHelper,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _priceValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _purchasePrice,
                decoration: InputDecoration(
                  labelText: l10n.productsCostPrice,
                  prefixText: '${AppStrings.currencySymbol} ',
                  helperText: l10n.productsCostPriceHelper,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _priceValidator,
              ),
              const SizedBox(height: AppSizes.md),
              // GST is derived from the HSN code, not typed — so it gets its
              // own full-width row rather than sharing one with cost price.
              // It carries a provenance line and, when a threshold rule
              // applies, the price it was decided against; none of that fits
              // in half a row next to another field.
              GstRateField(
                controller: _taxPercent,
                manual: _taxManual,
                onManualChanged: (v) => setState(() {
                  _taxManual = v;
                  _dirty = true;
                }),
                resolution: _rateForCurrentCode,
                unknownCode: _hsnUnknown,
              ),

              const SizedBox(height: AppSizes.xxl),

              // ── More details — optional, each opens full-screen ───────
              AppSectionHeader(
                title: l10n.productsSectionMoreDetails,
                padding: const EdgeInsets.only(bottom: AppSizes.xs),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.md),
                child: Text(
                  l10n.productsMoreDetailsIntro,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ),
              ..._detailTiles(),

              const SizedBox(height: AppSizes.huge),
            ],
          ),
        ),
      ),
    );
  }

  // ── Essentials sub-builders ─────────────────────────────────────────

  /// Unit dropdown — shows the short code when collapsed (so it fits a
  /// half-width slot) and the full label inside the menu.
  Widget _unitField() {
    final l10n = AppLocalizations.of(context);
    final value = AppUnits.all.contains(_selectedUnit)
        ? _selectedUnit
        : AppUnits.all.first;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.productsUnit),
      selectedItemBuilder: (_) =>
          AppUnits.all.map((u) => Text('$u — ${AppUnits.label(u)}')).toList(),
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
    );
  }

  Widget _categoryField(List<dynamic> categories) {
    final l10n = AppLocalizations.of(context);
    final selected = _selectedCategoryId == null
        ? null
        : categories
              .where((c) => c.id == _selectedCategoryId)
              .cast<dynamic>()
              .firstOrNull;
    final label = selected?.name ?? l10n.productsNone;
    final iconData = resolveCategoryIcon(selected?.iconName as String?);
    return InkWell(
      onTap: () async {
        final result = await CategoryPickerSheet.show(
          context,
          currentSelectionId: _selectedCategoryId,
        );
        if (result != null) {
          setState(() {
            _selectedCategoryId = result.categoryId;
            _dirty = true;
          });
        }
      },
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(labelText: l10n.productsCategory),
        child: Row(
          children: [
            AppIcon(iconData, size: 18, color: AppColors.muted),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            AppIcon(
              AppIcons.unfoldMoreRounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _photosSection() {
    final l10n = AppLocalizations.of(context);
    return [
      AppSectionHeader(
        title: l10n.productsProductImages.toUpperCase(),
        padding: const EdgeInsets.only(bottom: AppSizes.sm),
      ),
      if (_imageUrls.isNotEmpty) ...[
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _imageUrls.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
            itemBuilder: (ctx, i) => Stack(
              children: [
                ClipRRect(
                  borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
                  child: Image.network(
                    resolveImageUrl(_imageUrls[i]),
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 96,
                      height: 96,
                      decoration: ShapeDecoration(
                        color: AppColors.surface,
                        shape: AppShapes.squircle(
                          AppSizes.radiusMd,
                          side: BorderSide(color: AppColors.hairline, width: 1),
                        ),
                      ),
                      child: AppIcon(
                        AppIcons.brokenImageRounded,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: AppSizes.xs,
                  right: AppSizes.xs,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      final url = _imageUrls[i];
                      final existingId = _existingImageIdByUrl[url];
                      if (existingId != null) _removedImageIds.add(existingId);
                      _imageUrls.removeAt(i);
                      _dirty = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.inverseSurface,
                        shape: BoxShape.circle,
                      ),
                      child: AppIcon(
                        AppIcons.closeRounded,
                        size: 14,
                        color: AppColors.onInverse,
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
      // Gallery uses pickMultiImage so the merchant can drop a whole
      // product shoot in one tap; camera stays single because you can't
      // capture a batch in one shutter press.
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadMultiple,
              icon: const AppIcon(AppIcons.photoLibraryRounded, size: 18),
              label: Text(l10n.productsPickFromGallery),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isUploading
                  ? null
                  : () => _pickAndUploadImage(ImageSource.camera),
              icon: const AppIcon(AppIcons.cameraAltRounded, size: 18),
              label: Text(l10n.productsTakePhoto),
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: AppSizes.xs),
        child: Text(
          _imageUrls.isEmpty
              ? l10n.productsGalleryEmptyHint('$_maxGalleryImages')
              : l10n.productsGalleryCountHint(
                  '${_imageUrls.length}',
                  '$_maxGalleryImages',
                ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ),
      if (_isUploading) ...[
        const SizedBox(height: AppSizes.sm),
        const LinearProgressIndicator(),
      ],
      const SizedBox(height: AppSizes.sm),
      // URL fallback — collapsed behind an expansion so it doesn't clutter
      // the common gallery/camera path.
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: AppSizes.sm),
          title: Text(
            l10n.productsAddByImageLink,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _imageUrlController,
                    decoration: InputDecoration(
                      labelText: l10n.productsAddImageUrl,
                      hintText: l10n.productsImageUrlHint,
                    ),
                    keyboardType: TextInputType.url,
                    onFieldSubmitted: (_) => _addImageUrl(),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                IconButton.filled(
                  onPressed: _addImageUrl,
                  icon: const AppIcon(AppIcons.linkRounded),
                  tooltip: l10n.productsAddImage,
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // ── "More details" hub ──────────────────────────────────────────────

  List<Widget> _detailTiles() {
    final l10n = AppLocalizations.of(context);
    final specRows = _specs.fold<int>(0, (n, g) => n + g.rows.length);
    final customSet = _customFieldValues.values
        .where((v) => v.trim().isNotEmpty)
        .length;
    final tiles = <Widget>[
      _DetailTile(
        icon: AppIcons.boltOutlined,
        title: l10n.productsHighlightsTitle,
        subtitle: l10n.productsHighlightsSubtitle,
        count: _highlights.length,
        onTap: () => _openEditor(
          title: l10n.productsHighlightsTitle,
          intro: l10n.productsHighlightsIntro,
          builder: (refresh) => _HighlightsEditor(
            items: _highlights,
            controller: _highlightController,
            onAdd: () {
              _addHighlight();
              refresh();
            },
            onRemove: (i) {
              _highlights.removeAt(i);
              _dirty = true;
              refresh();
            },
          ),
        ),
      ),
      _DetailTile(
        icon: AppIcons.factCheckOutlined,
        title: l10n.productsSpecificationsTitle,
        subtitle: l10n.productsSpecificationsSubtitle,
        count: specRows,
        onTap: () => _openEditor(
          title: l10n.productsSpecificationsTitle,
          intro: l10n.productsSpecificationsIntro,
          builder: (_) => _SpecsEditor(groups: _specs, onChange: _markDirty),
        ),
      ),
      _DetailTile(
        icon: AppIcons.localOfferOutlined,
        title: l10n.productsOffersTitle,
        subtitle: l10n.productsOffersSubtitle,
        count: _offers.length,
        onTap: () => _openEditor(
          title: l10n.productsOffersTitle,
          intro: l10n.productsOffersIntro,
          builder: (_) => _OffersEditor(offers: _offers, onChange: _markDirty),
        ),
      ),
      _DetailTile(
        icon: AppIcons.articleOutlined,
        title: l10n.productsRichDescriptionTitle,
        subtitle: l10n.productsRichDescriptionSubtitle,
        count: _contentBlocks.length,
        onTap: () => _openEditor(
          title: l10n.productsRichDescriptionShort,
          intro: l10n.productsRichDescriptionIntro,
          builder: (_) => ContentBlocksEditor(
            blocks: _contentBlocks,
            onChange: _markDirty,
            onPickImage: () => _pickAndUploadVariantImage(ImageSource.gallery),
          ),
        ),
      ),
      _DetailTile(
        icon: AppIcons.styleOutlined,
        title: l10n.productsVariantsTitle,
        subtitle: l10n.productsVariantsSubtitle,
        count: _variants.where((v) => !v.isDefault).length,
        onTap: () => _openEditor(
          title: l10n.productsVariantsTitle,
          intro: l10n.productsVariantsIntro,
          builder: (_) => VariantsEditor(
            axes: _variantAxes,
            variants: _variants,
            defaultMrp: double.tryParse(_mrp.text) ?? 0,
            defaultSellingPrice: double.tryParse(_sellingPrice.text) ?? 0,
            defaultPurchasePrice: double.tryParse(_purchasePrice.text) ?? 0,
            defaultSku: _sku.text,
            onChange: _markDirty,
            onUploadImage: _pickAndUploadVariantImage,
          ),
        ),
      ),
      _DetailTile(
        icon: AppIcons.sellOutlined,
        title: l10n.productsTagsTitle,
        subtitle: l10n.productsTagsSubtitle,
        count: _tags.length,
        onTap: () => _openEditor(
          title: l10n.productsTagsTitle,
          intro: l10n.productsTagsIntro,
          builder: (refresh) => _TagsEditor(
            tags: _tags,
            controller: _tagController,
            onAdd: () {
              _addTagFromInput();
              refresh();
            },
            onRemove: (t) {
              _tags.remove(t);
              _dirty = true;
              refresh();
            },
          ),
        ),
      ),
      _DetailTile(
        icon: AppIcons.dashboardCustomizeOutlined,
        title: l10n.productsMoreAboutTitle,
        subtitle: l10n.productsMoreAboutSubtitle,
        count: customSet,
        onTap: () => _openEditor(
          title: l10n.productsMoreAboutTitle,
          intro: l10n.productsMoreAboutIntro,
          builder: (_) => CustomFieldsFormSection(
            values: _customFieldValues,
            onValueChanged: (id, value) {
              _customFieldValues[id] = value;
              _dirty = true;
            },
          ),
        ),
      ),
    ];

    return [
      for (final t in tiles) ...[t, const SizedBox(height: AppSizes.sm)],
    ];
  }
}

/// One row in the "More details" hub — icon, title, helper line, a count
/// badge when the section already has content, and a chevron. Tapping
/// opens that section full-screen.
class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.count = 0,
  });
  final AppIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.surface,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(color: AppColors.hairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: AppSizes.avatarSm,
              height: AppSizes.avatarSm,
              decoration: ShapeDecoration(
                color: AppColors.surfaceTint,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: AppIcon(
                icon,
                size: AppSizes.iconMd,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.bold),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: 3,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.extraBold,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
            ],
            AppIcon(AppIcons.chevronRightRounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Full-screen host for an advanced section. A plain app bar with a Done
/// button, an optional intro line, and the section's editor below. The
/// [builder] gets a `refresh` callback so editors that don't manage
/// their own state can ask this scaffold to rebuild.
class _EditorScaffold extends StatefulWidget {
  const _EditorScaffold({
    required this.title,
    required this.builder,
    this.intro,
  });
  final String title;
  final String? intro;
  final Widget Function(void Function() refresh) builder;

  @override
  State<_EditorScaffold> createState() => _EditorScaffoldState();
}

class _EditorScaffoldState extends State<_EditorScaffold> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: widget.title,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.productsDone),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.lg + FloatingAppBar.contentTopInset(context),
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.intro != null) ...[
              Text(
                widget.intro!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSizes.lg),
            ],
            widget.builder(() => setState(() {})),
          ],
        ),
      ),
    );
  }
}

/// Chip-input tags editor — type a tag + comma / enter to add. Caps
/// at 20 (server also enforces); duplicates ignored case-insensitively
/// in `_addTagFromInput` above.
class _TagsEditor extends StatelessWidget {
  const _TagsEditor({
    required this.tags,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> tags;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final t in tags)
              Chip(
                label: Text(t),
                onDeleted: () => onRemove(t),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (tags.isNotEmpty) const SizedBox(height: AppSizes.sm),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.productsAddTag,
            helperText: l10n.productsTagsIntro,
            suffixIcon: IconButton(
              icon: const AppIcon(AppIcons.addRounded),
              onPressed: onAdd,
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onAdd(),
        ),
      ],
    );
  }
}

/// Bulleted list editor for the V2 PDP highlights — drop a sentence
/// in, hit + to add. Capped at 8 because the customer surface only
/// renders the top few; more is just noise.
class _HighlightsEditor extends StatelessWidget {
  const _HighlightsEditor({
    required this.items,
    required this.controller,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> items;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Row(
              children: [
                Text(
                  '• ',
                  style: Theme.of(context).textTheme.bodyMedium?.extraBold,
                ),
                Expanded(child: Text(items[i])),
                IconButton(
                  icon: const AppIcon(AppIcons.closeRounded, size: 18),
                  onPressed: () => onRemove(i),
                  tooltip: l10n.productsRemove,
                ),
              ],
            ),
          ),
        if (items.length < 8)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLength: 140,
                  decoration: InputDecoration(
                    hintText: l10n.productsAddHighlightHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    counterText: '',
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              IconButton.filled(
                onPressed: onAdd,
                icon: const AppIcon(AppIcons.add),
              ),
            ],
          ),
      ],
    );
  }
}

/// Stateful spec-sheet editor. Each group has a title + N rows; the
/// inline state is intentional — wrapping a nested editor in callbacks
/// is fiddlier than mutating in place + telling the parent the form
/// is dirty via [onChange].
class _SpecsEditor extends StatefulWidget {
  const _SpecsEditor({required this.groups, required this.onChange});
  final List<SpecGroup> groups;
  final VoidCallback onChange;
  @override
  State<_SpecsEditor> createState() => _SpecsEditorState();
}

class _SpecsEditorState extends State<_SpecsEditor> {
  void _addGroup() {
    setState(() {
      widget.groups.add(
        const SpecGroup(
          title: '',
          rows: [SpecRow(label: '', value: '')],
        ),
      );
    });
    widget.onChange();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var gi = 0; gi < widget.groups.length; gi++)
          _GroupCard(
            group: widget.groups[gi],
            onChangeTitle: (t) {
              setState(
                () => widget.groups[gi] = widget.groups[gi].copyWith(title: t),
              );
              widget.onChange();
            },
            onChangeTab: (t) {
              setState(
                () => widget.groups[gi] = widget.groups[gi].copyWith(
                  tab: t.trim().isEmpty ? null : t.trim(),
                ),
              );
              widget.onChange();
            },
            onChangeRow: (ri, row) {
              setState(() {
                final next = List<SpecRow>.from(widget.groups[gi].rows);
                next[ri] = row;
                widget.groups[gi] = widget.groups[gi].copyWith(rows: next);
              });
              widget.onChange();
            },
            onAddRow: () {
              setState(() {
                final next = List<SpecRow>.from(widget.groups[gi].rows)
                  ..add(const SpecRow(label: '', value: ''));
                widget.groups[gi] = widget.groups[gi].copyWith(rows: next);
              });
              widget.onChange();
            },
            onRemoveRow: (ri) {
              setState(() {
                final next = List<SpecRow>.from(widget.groups[gi].rows)
                  ..removeAt(ri);
                if (next.isEmpty) {
                  widget.groups.removeAt(gi);
                } else {
                  widget.groups[gi] = widget.groups[gi].copyWith(rows: next);
                }
              });
              widget.onChange();
            },
            onRemoveGroup: () {
              setState(() => widget.groups.removeAt(gi));
              widget.onChange();
            },
          ),
        OutlinedButton.icon(
          onPressed: widget.groups.length >= 10 ? null : _addGroup,
          icon: const AppIcon(AppIcons.add),
          label: Text(l10n.productsAddSpecGroup),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onChangeTitle,
    required this.onChangeTab,
    required this.onChangeRow,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onRemoveGroup,
  });
  final SpecGroup group;
  final ValueChanged<String> onChangeTitle;
  final ValueChanged<String> onChangeTab;
  final void Function(int, SpecRow) onChangeRow;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onRemoveGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: group.title,
                  onChanged: onChangeTitle,
                  decoration: InputDecoration(
                    labelText: l10n.productsGroupTitleLabel,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const AppIcon(AppIcons.deleteOutline),
                onPressed: onRemoveGroup,
                tooltip: l10n.productsRemoveGroup,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          // Optional subtab — when any group on a product carries one,
          // the customer PDP chips the unique tabs above the spec
          // table and filters groups by selection. Leave blank for a
          // flat spec list (the default).
          TextFormField(
            initialValue: group.tab ?? '',
            onChanged: onChangeTab,
            decoration: InputDecoration(
              labelText: l10n.productsTabLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          // Each attribute stacks label-over-value full width so long
          // labels ("In the box") and long values aren't clipped the way
          // the old side-by-side layout cut them off.
          for (var i = 0; i < group.rows.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: AppSizes.sm),
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                AppSizes.xs,
                AppSizes.xs,
                AppSizes.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: group.rows[i].label,
                          onChanged: (v) =>
                              onChangeRow(i, group.rows[i].copyWith(label: v)),
                          decoration: InputDecoration(
                            labelText: l10n.productsSpecLabelLabel,
                            hintText: l10n.productsSpecLabelHint,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const AppIcon(AppIcons.closeRounded, size: 18),
                        tooltip: l10n.productsRemoveRow,
                        onPressed: () => onRemoveRow(i),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSizes.sm),
                    child: TextFormField(
                      initialValue: group.rows[i].value,
                      onChanged: (v) =>
                          onChangeRow(i, group.rows[i].copyWith(value: v)),
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l10n.productsSpecValueLabel,
                        hintText: l10n.productsSpecValueHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: group.rows.length >= 20 ? null : onAddRow,
            icon: const AppIcon(AppIcons.add, size: 18),
            label: Text(l10n.productsAddRow),
          ),
        ],
      ),
    );
  }
}

/// Add/remove per-product offers. Coupon / EMI / Exchange — bank
/// offers deliberately omitted: those are platform-wide tie-ups
/// curated centrally by admins (see `PlatformBankOffer` on the
/// backend). Letting individual merchants invent their own bank
/// offers would (a) let them promise discounts a bank never agreed
/// to fund, and (b) force them to re-type the same HDFC strip on
/// every product. The PDP merges these merchant-scoped offers with
/// the platform bank feed at render time.
class _OffersEditor extends StatefulWidget {
  const _OffersEditor({required this.offers, required this.onChange});
  final List<ProductOffer> offers;
  final VoidCallback onChange;
  @override
  State<_OffersEditor> createState() => _OffersEditorState();
}

class _OffersEditorState extends State<_OffersEditor> {
  static const _kinds = <String>['COUPON', 'EMI', 'EXCHANGE'];

  void _addOffer() {
    setState(
      () => widget.offers.add(const ProductOffer(kind: 'COUPON', headline: '')),
    );
    widget.onChange();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Bank offers were removed from this editor — surface that to the
    // merchant explicitly so they don't go looking for the option.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppSizes.md),
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.infoSoft,
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(
                AppIcons.accountBalanceOutlined,
                size: AppSizes.iconSm,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  l10n.productsBankOffersNote,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < widget.offers.length; i++)
          _OfferRow(
            key: ValueKey('offer-$i-${widget.offers[i].kind}'),
            offer: widget.offers[i],
            onChange: (next) {
              setState(() => widget.offers[i] = next);
              widget.onChange();
            },
            onRemove: () {
              setState(() => widget.offers.removeAt(i));
              widget.onChange();
            },
            kinds: _kinds,
          ),
        OutlinedButton.icon(
          onPressed: widget.offers.length >= 6 ? null : _addOffer,
          icon: const AppIcon(AppIcons.add),
          label: Text(l10n.productsAddOffer),
        ),
      ],
    );
  }
}

/// One offer row in the editor — freeform headline / detail / code.
/// Kept as its own widget (rather than inlined into the editor's
/// build) so each row owns its TextEditingControllers and the kind
/// dropdown doesn't fight other rows for focus on rebuild.
class _OfferRow extends StatefulWidget {
  const _OfferRow({
    super.key,
    required this.offer,
    required this.onChange,
    required this.onRemove,
    required this.kinds,
  });
  final ProductOffer offer;
  final ValueChanged<ProductOffer> onChange;
  final VoidCallback onRemove;
  final List<String> kinds;

  @override
  State<_OfferRow> createState() => _OfferRowState();
}

class _OfferRowState extends State<_OfferRow> {
  late TextEditingController _headline;
  late TextEditingController _detail;
  late TextEditingController _code;

  @override
  void initState() {
    super.initState();
    _headline = TextEditingController(text: widget.offer.headline);
    _detail = TextEditingController(text: widget.offer.detail ?? '');
    _code = TextEditingController(text: widget.offer.code ?? '');
  }

  @override
  void dispose() {
    _headline.dispose();
    _detail.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  // Legacy BANK rows fall back to COUPON in the picker
                  // (the on-wire `kind` stays as-is until the merchant
                  // picks something explicitly). The PDP filters BANK
                  // out of per-product offers regardless.
                  initialValue: widget.kinds.contains(widget.offer.kind)
                      ? widget.offer.kind
                      : 'COUPON',
                  decoration: InputDecoration(
                    labelText: l10n.productsOfferKind,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final k in widget.kinds)
                      DropdownMenuItem(value: k, child: Text(k)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    widget.onChange(widget.offer.copyWith(kind: v));
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const AppIcon(AppIcons.deleteOutline),
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          TextFormField(
            controller: _headline,
            onChanged: (v) =>
                widget.onChange(widget.offer.copyWith(headline: v)),
            decoration: InputDecoration(
              labelText: l10n.productsOfferHeadline,
              hintText: l10n.productsOfferHeadlineHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _detail,
                  onChanged: (v) =>
                      widget.onChange(widget.offer.copyWith(detail: v)),
                  decoration: InputDecoration(
                    labelText: l10n.productsOfferDetail,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              SizedBox(
                width: 140,
                child: TextFormField(
                  controller: _code,
                  onChanged: (v) =>
                      widget.onChange(widget.offer.copyWith(code: v)),
                  decoration: InputDecoration(
                    labelText: l10n.productsOfferCode,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
