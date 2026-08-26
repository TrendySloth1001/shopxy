import 'package:shopxy/features/categories/domain/entities/category.dart';

class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.url,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String productId;
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
    this.taxSource = 'MANUAL',
    this.pricingMode = 'TAX_EXCLUSIVE',
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

  final String id;
  final String name;
  final String? description;
  final String sku;
  final String? barcode;
  final String? hsnCode;
  final String? brand;
  final double mrp;
  final double sellingPrice;
  final double purchasePrice;
  final double taxPercent;

  final String taxSource;

  final String pricingMode;
  final double stockQuantity;
  final double lowStockThreshold;
  final String unit;
  final String? categoryId;
  final Category? category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductImage> images;

  final DateTime? lastStockInAt;

  final DateTime? lastStockOutAt;

  final String? lastVendorId;

  final String? lastVendorName;

  final bool isPublished;

  final double? ratingAvg;
  final int ratingCount;

  final List<String> tags;

  final List<String> highlights;

  final List<SpecGroup> specs;

  final List<ProductOffer> offers;

  final int totalSold;

  final int soldLast30d;

  final List<String> systemTags;

  final List<ContentBlock> contentBlocks;

  final List<VariantAxis> variantAxes;

  final List<ProductVariant> variants;

  String? get primaryImageUrl => images.isNotEmpty ? images.first.url : null;
  bool get isLowStock => stockQuantity <= lowStockThreshold && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;
  double get profit => sellingPrice - purchasePrice;
  double get margin => purchasePrice > 0 ? (profit / sellingPrice) * 100 : 0;
}

class SpecGroup {
  const SpecGroup({required this.title, this.tab, required this.rows});
  final String title;

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

  final String? id;
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
    String? id,
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
      id: j['id']?.toString(),
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

class ContentBlock {
  const ContentBlock({required this.kind, required this.data});

  final String kind;

  final Map<String, dynamic> data;

  ContentBlock copyWith({String? kind, Map<String, dynamic>? data}) =>
      ContentBlock(kind: kind ?? this.kind, data: data ?? this.data);

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
