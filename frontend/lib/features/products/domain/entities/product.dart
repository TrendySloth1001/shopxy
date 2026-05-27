import 'package:shopxy/features/categories/domain/entities/category.dart';

class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.url,
    required this.sortOrder,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final String url;
  final int sortOrder;
  final DateTime createdAt;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.sku,
    this.barcode,
    this.hsnCode,
    this.brand,
    required this.mrp,
    required this.sellingPrice,
    required this.purchasePrice,
    required this.taxPercent,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.unit,
    this.categoryId,
    this.category,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.lastStockInAt,
    this.lastStockOutAt,
    this.lastVendorId,
    this.lastVendorName,
    this.isPublished = false,
    this.ratingAvg,
    this.ratingCount = 0,
    this.tags = const [],
    this.highlights = const [],
    this.specs = const [],
    this.offers = const [],
    this.totalSold = 0,
    this.soldLast30d = 0,
    this.systemTags = const [],
    this.contentBlocks = const [],
    this.variantAxes = const [],
    this.variants = const [],
  });

  final int id;
  final String name;
  final String? description;
  final String sku;
  final String? barcode;
  final String? hsnCode;
  /// Free-text brand name surfaced on the PDP under the title. Null
  /// for merchants who don't carry branded inventory.
  final String? brand;
  final double mrp;
  final double sellingPrice;
  final double purchasePrice;
  final double taxPercent;
  final double stockQuantity;
  final double lowStockThreshold;
  final String unit;
  final int? categoryId;
  final Category? category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductImage> images;

  /// Most recent STOCK_IN ledger timestamp for this product, when one exists.
  /// Powers the "Stocked in 2d ago" hint on the merchant product list.
  final DateTime? lastStockInAt;

  /// Most recent STOCK_OUT ledger timestamp. Used for "Sold 3d ago" and
  /// "Out since 5d ago" framings.
  final DateTime? lastStockOutAt;

  /// Vendor id for the supplier of the most recent STOCK_IN, when the
  /// transaction recorded a real vendor (not a free-text supplier).
  final int? lastVendorId;

  /// Vendor display name paired with [lastVendorId].
  final String? lastVendorName;

  /// Marketplace publish state — false means the SKU is internal-only.
  final bool isPublished;

  /// Mean review rating; null until the first review lands.
  final double? ratingAvg;
  final int ratingCount;

  /// Free-form merchant-curated tags (Bestseller, Eco-friendly, ...).
  final List<String> tags;

  /// Short above-the-fold bullet points for the V2 PDP. Different
  /// rendering shape from [tags] — these are descriptive sentences,
  /// not keywords. Stored backend-side as a Postgres text[].
  final List<String> highlights;

  /// Long-form spec sheet, grouped by section. Backend stores this as
  /// JSONB to keep the cross-category shape flexible.
  final List<SpecGroup> specs;

  /// Bank / coupon / EMI / exchange offers shown beneath the price.
  /// Same JSONB-backed flexibility.
  final List<ProductOffer> offers;

  /// Lifetime sold quantity, updated by the backend Phase-1 backfill +
  /// (in a later phase) on every CONFIRMED invoice.
  final int totalSold;

  /// Trailing-30-day sold quantity, refreshed nightly by the scheduler.
  /// Drives the "X bought in past month" line on the PDP.
  final int soldLast30d;

  /// Curated, system-managed tags (BESTSELLER, EDITORS_PICK, etc).
  /// Merchants can't write these — they're set by admin or the
  /// trending job. Mirrors the backend `system_tags` column.
  final List<String> systemTags;

  /// A+ content blocks rendered in the customer PDP Details tab.
  /// Empty when the merchant hasn't authored any.
  final List<ContentBlock> contentBlocks;

  /// Phase E — variant axis definitions ([{name, values}]). Empty
  /// when the product is single-variant (still has one default
  /// variant under the hood).
  final List<VariantAxis> variantAxes;

  /// Phase E — purchasable SKUs under this product. Always has at
  /// least one row (the default variant). Multi-variant products
  /// surface a swatch picker on the PDP.
  final List<ProductVariant> variants;

  String? get primaryImageUrl => images.isNotEmpty ? images.first.url : null;
  bool get isLowStock => stockQuantity <= lowStockThreshold && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;
  double get profit => sellingPrice - purchasePrice;
  double get margin => purchasePrice > 0 ? (profit / sellingPrice) * 100 : 0;
}

/// One section of the spec sheet — title plus rows of (label, value)
/// pairs. Empty rows are allowed mid-edit; the DTO trims them before
/// posting so we never round-trip useless data.
class SpecGroup {
  const SpecGroup({required this.title, this.tab, required this.rows});
  final String title;

  /// Phase D — optional subtab bucket. When any group on a product
  /// declares a tab, the PDP renders a chip row above the spec table
  /// and filters by selection. Null on every group ⇒ legacy flat list.
  final String? tab;
  final List<SpecRow> rows;

  SpecGroup copyWith({String? title, String? tab, List<SpecRow>? rows}) =>
      SpecGroup(
          title: title ?? this.title,
          tab: tab ?? this.tab,
          rows: rows ?? this.rows);

  Map<String, dynamic> toJson() => {
        'title': title,
        if (tab != null && tab!.isNotEmpty) 'tab': tab,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory SpecGroup.fromJson(Map<String, dynamic> j) => SpecGroup(
        title: (j['title'] as String?) ?? '',
        tab: (j['tab'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['tab'] as String).trim(),
        rows: ((j['rows'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SpecRow.fromJson)
            .toList(),
      );
}

class SpecRow {
  const SpecRow({required this.label, required this.value});
  final String label;
  final String value;

  SpecRow copyWith({String? label, String? value}) =>
      SpecRow(label: label ?? this.label, value: value ?? this.value);

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  factory SpecRow.fromJson(Map<String, dynamic> j) =>
      SpecRow(label: (j['label'] as String?) ?? '', value: (j['value'] as String?) ?? '');
}

/// One bank / coupon / EMI / exchange offer. `kind` is a string (not
/// an enum) so the merchant editor + backend can add new kinds
/// without forcing a new app build.
class ProductOffer {
  const ProductOffer({
    required this.kind,
    required this.headline,
    this.detail,
    this.code,
  });

  final String kind;
  final String headline;
  final String? detail;
  final String? code;

  ProductOffer copyWith({String? kind, String? headline, String? detail, String? code}) =>
      ProductOffer(
        kind: kind ?? this.kind,
        headline: headline ?? this.headline,
        detail: detail ?? this.detail,
        code: code ?? this.code,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'headline': headline,
        if (detail != null && detail!.isNotEmpty) 'detail': detail,
        if (code != null && code!.isNotEmpty) 'code': code,
      };

  factory ProductOffer.fromJson(Map<String, dynamic> j) => ProductOffer(
        kind: (j['kind'] as String?) ?? 'COUPON',
        headline: (j['headline'] as String?) ?? '',
        detail: j['detail'] as String?,
        code: j['code'] as String?,
      );
}

/// Phase E — variant axis definition. [name] is the axis label
/// ("Color"), [values] are the picker options ("Red", "Blue", ...).
class VariantAxis {
  const VariantAxis({required this.name, required this.values});
  final String name;
  final List<String> values;

  VariantAxis copyWith({String? name, List<String>? values}) =>
      VariantAxis(name: name ?? this.name, values: values ?? this.values);

  Map<String, dynamic> toJson() => {'name': name, 'values': values};

  factory VariantAxis.fromJson(Map<String, dynamic> j) => VariantAxis(
        name: (j['name'] as String?) ?? '',
        values: ((j['values'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

/// Phase E — a single purchasable SKU under a product. Carries its own
/// pricing/stock/images plus a free-form [attributes] map keyed by the
/// owning product's [VariantAxis] names.
class ProductVariant {
  const ProductVariant({
    this.id,
    required this.sku,
    this.barcode,
    required this.attributes,
    required this.mrp,
    required this.sellingPrice,
    required this.purchasePrice,
    this.stockQuantity = 0,
    this.imageUrls = const [],
    this.isDefault = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  /// Null for a not-yet-saved variant; the backend assigns on first save.
  final int? id;
  final String sku;
  final String? barcode;
  final Map<String, String> attributes;
  final double mrp;
  final double sellingPrice;
  final double purchasePrice;
  final double stockQuantity;
  final List<String> imageUrls;
  final bool isDefault;
  final bool isActive;
  final int sortOrder;

  ProductVariant copyWith({
    int? id,
    String? sku,
    String? barcode,
    Map<String, String>? attributes,
    double? mrp,
    double? sellingPrice,
    double? purchasePrice,
    double? stockQuantity,
    List<String>? imageUrls,
    bool? isDefault,
    bool? isActive,
    int? sortOrder,
  }) =>
      ProductVariant(
        id: id ?? this.id,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        attributes: attributes ?? this.attributes,
        mrp: mrp ?? this.mrp,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        imageUrls: imageUrls ?? this.imageUrls,
        isDefault: isDefault ?? this.isDefault,
        isActive: isActive ?? this.isActive,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'sku': sku,
        if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
        'attributes': attributes,
        'mrp': mrp,
        'sellingPrice': sellingPrice,
        'purchasePrice': purchasePrice,
        'stockQuantity': stockQuantity,
        'imageUrls': imageUrls,
        'isActive': isActive,
        'sortOrder': sortOrder,
      };

  factory ProductVariant.fromJson(Map<String, dynamic> j) {
    final attrs = (j['attributes'] as Map?) ?? const {};
    return ProductVariant(
      id: (j['id'] as num?)?.toInt(),
      sku: (j['sku'] as String?) ?? '',
      barcode: j['barcode'] as String?,
      attributes: <String, String>{
        for (final e in attrs.entries) e.key.toString(): e.value.toString(),
      },
      mrp: _toDouble(j['mrp']),
      sellingPrice: _toDouble(j['sellingPrice']),
      purchasePrice: _toDouble(j['purchasePrice']),
      stockQuantity: _toDouble(j['stockQuantity']),
      imageUrls:
          ((j['imageUrls'] as List<dynamic>?) ?? const []).cast<String>(),
      isDefault: (j['isDefault'] as bool?) ?? false,
      isActive: (j['isActive'] as bool?) ?? true,
      sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

/// Phase C — A+ content block. Discriminated by [kind]; per-kind fields
/// live in [data]. Kept as a single class (rather than a sealed
/// hierarchy) so adding a new kind is a server-side change only — the
/// merchant editor + customer renderer use a `kind`-based switch and
/// fall back to a "Untitled" block when they see something newer than
/// they ship with. Same forward-compat strategy as [ProductOffer].
class ContentBlock {
  const ContentBlock({required this.kind, required this.data});

  /// 'HERO' | 'FEATURE' | 'COMPARISON' | 'GALLERY' | 'TEXT'
  final String kind;

  /// Per-kind payload — see backend `contentBlockSchema` for shapes.
  final Map<String, dynamic> data;

  ContentBlock copyWith({String? kind, Map<String, dynamic>? data}) =>
      ContentBlock(kind: kind ?? this.kind, data: data ?? this.data);

  /// Strips keys starting with `_` (editor-local scratch fields like
  /// `_draft` used by the COMPARISON textarea) before serialising.
  Map<String, dynamic> toJson() {
    final clean = <String, dynamic>{};
    data.forEach((k, v) {
      if (!k.startsWith('_')) clean[k] = v;
    });
    return {'kind': kind, ...clean};
  }

  factory ContentBlock.fromJson(Map<String, dynamic> j) {
    final data = Map<String, dynamic>.from(j);
    final kind = (data.remove('kind') as String?) ?? 'TEXT';
    return ContentBlock(kind: kind, data: data);
  }
}
