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
  });

  final int id;
  final String name;
  final String? description;
  final String sku;
  final String? barcode;
  final String? hsnCode;
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
  const SpecGroup({required this.title, required this.rows});
  final String title;
  final List<SpecRow> rows;

  SpecGroup copyWith({String? title, List<SpecRow>? rows}) =>
      SpecGroup(title: title ?? this.title, rows: rows ?? this.rows);

  Map<String, dynamic> toJson() => {
        'title': title,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory SpecGroup.fromJson(Map<String, dynamic> j) => SpecGroup(
        title: (j['title'] as String?) ?? '',
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
