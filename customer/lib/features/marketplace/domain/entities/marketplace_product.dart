import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_shop.dart';

class MarketplaceProduct {
  const MarketplaceProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.mrp,
    required this.sellingPrice,
    required this.taxPercent,
    required this.stockQuantity,
    required this.images,
    required this.tags,
    required this.highlights,
    required this.specs,
    required this.offers,
    required this.totalSold,
    this.description,
    this.countryOfOrigin,
    this.ratingAvg,
    this.ratingCount = 0,
    this.shop,
    this.category,
    this.brand,
    this.soldLast30d = 0,
    this.systemTags = const [],
    this.contentBlocks = const [],
    this.variantAxes = const [],
    this.variants = const [],
  });

  final String id;
  final String name;
  final String sku;
  final String unit;
  final double mrp;
  final double sellingPrice;
  final double taxPercent;
  final double stockQuantity;
  final List<String> images;
  final List<String> tags;

  final List<String> highlights;

  final List<SpecGroup> specs;

  final List<ProductOffer> offers;
  final int totalSold;
  final String? description;

  final String? countryOfOrigin;
  final double? ratingAvg;
  final int ratingCount;
  final MarketplaceShop? shop;
  final ProductCategoryRef? category;

  final String? brand;

  final int soldLast30d;

  final List<String> systemTags;

  final List<ContentBlock> contentBlocks;

  final List<MarketplaceVariantAxis> variantAxes;

  final List<MarketplaceVariant> variants;

  MarketplaceVariant? get defaultVariant {
    if (variants.isEmpty) return null;
    for (final v in variants) {
      if (v.isDefault) return v;
    }
    return variants.first;
  }

  bool get inStock => stockQuantity > 0;
  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;
  int get discountPct {
    if (mrp <= 0 || sellingPrice <= 0 || mrp <= sellingPrice) return 0;
    return (((mrp - sellingPrice) / mrp) * 100).round();
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory MarketplaceProduct.fromJson(Map<String, dynamic> j) {
    final imageList = (j['images'] as List<dynamic>? ?? [])
        .map((e) => (e as Map<String, dynamic>)['url'] as String?)
        .whereType<String>()
        .toList();
    final specRaw = j['specs'];
    final offersRaw = j['offers'];
    return MarketplaceProduct(
      id: j['id'].toString(),
      name: j['name'] as String,
      sku: j['sku'] as String,
      unit: j['unit'] as String? ?? 'PCS',
      mrp: _asDouble(j['mrp']),
      sellingPrice: _asDouble(j['sellingPrice']),
      taxPercent: _asDouble(j['taxPercent']),
      stockQuantity: _asDouble(j['stockQuantity']),
      images: imageList,
      tags: (j['tags'] as List<dynamic>? ?? []).cast<String>(),
      highlights: (j['highlights'] as List<dynamic>? ?? []).cast<String>(),
      specs: specRaw is List
          ? specRaw
              .whereType<Map<String, dynamic>>()
              .map(SpecGroup.fromJson)
              .where((g) => g.rows.isNotEmpty)
              .toList()
          : const [],
      offers: offersRaw is List
          ? offersRaw
              .whereType<Map<String, dynamic>>()
              .map(ProductOffer.fromJson)
              .toList()
          : const [],
      totalSold: j['totalSold'] as int? ?? 0,
      description: j['description'] as String?,
      countryOfOrigin: (j['countryOfOrigin'] as String?)?.trim().isEmpty == false
          ? (j['countryOfOrigin'] as String).trim()
          : null,
      ratingAvg: j['ratingAvg'] == null ? null : _asDouble(j['ratingAvg']),
      ratingCount: j['ratingCount'] as int? ?? 0,
      shop: j['shop'] is Map<String, dynamic>
          ? MarketplaceShop.fromJson(j['shop'] as Map<String, dynamic>)
          : null,
      category: j['category'] is Map<String, dynamic>
          ? ProductCategoryRef.fromJson(j['category'] as Map<String, dynamic>)
          : null,
      brand: (j['brand'] as String?)?.trim().isEmpty == false
          ? (j['brand'] as String).trim()
          : null,
      soldLast30d: (j['soldLast30d'] as num?)?.toInt() ?? 0,
      systemTags:
          (j['systemTags'] as List<dynamic>?)?.cast<String>() ?? const [],
      contentBlocks: (j['contentBlocks'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ContentBlock.fromJson)
              .toList() ??
          const [],
      variantAxes: (j['variantAxes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(MarketplaceVariantAxis.fromJson)
              .toList() ??
          const [],
      variants: (j['variants'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(MarketplaceVariant.fromJson)
              .toList() ??
          const [],
    );
  }

}

class MarketplaceVariantAxis {
  const MarketplaceVariantAxis({required this.name, required this.values});
  final String name;
  final List<String> values;

  factory MarketplaceVariantAxis.fromJson(Map<String, dynamic> j) =>
      MarketplaceVariantAxis(
        name: (j['name'] as String?) ?? '',
        values: ((j['values'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

class MarketplaceVariant {
  const MarketplaceVariant({
    required this.id,
    required this.sku,
    required this.attributes,
    required this.mrp,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.imageUrls,
    required this.isDefault,
  });

  final String id;
  final String sku;
  final Map<String, String> attributes;
  final double mrp;
  final double sellingPrice;
  final double stockQuantity;
  final List<String> imageUrls;
  final bool isDefault;

  bool get inStock => stockQuantity > 0;
  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;
  int get discountPct {
    if (mrp <= 0 || sellingPrice <= 0 || mrp <= sellingPrice) return 0;
    return (((mrp - sellingPrice) / mrp) * 100).round();
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory MarketplaceVariant.fromJson(Map<String, dynamic> j) {
    final attrs = (j['attributes'] as Map?) ?? const {};
    return MarketplaceVariant(
      id: j['id'].toString(),
      sku: (j['sku'] as String?) ?? '',
      attributes: <String, String>{
        for (final e in attrs.entries)
          e.key.toString(): e.value?.toString() ?? '',
      },
      mrp: _asDouble(j['mrp']),
      sellingPrice: _asDouble(j['sellingPrice']),
      stockQuantity: _asDouble(j['stockQuantity']),
      imageUrls:
          ((j['imageUrls'] as List<dynamic>?) ?? const []).cast<String>(),
      isDefault: (j['isDefault'] as bool?) ?? false,
    );
  }
}

class MarketplaceFbtCard {
  const MarketplaceFbtCard({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.mrp,
    required this.imageUrl,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final double sellingPrice;
  final double mrp;
  final String? imageUrl;
  final double? ratingAvg;
  final int ratingCount;

  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory MarketplaceFbtCard.fromJson(Map<String, dynamic> j) {
    final imgs = j['images'] as List<dynamic>? ?? const [];
    final firstUrl = imgs.isEmpty
        ? null
        : (imgs.first as Map<String, dynamic>)['url'] as String?;
    return MarketplaceFbtCard(
      id: j['id'].toString(),
      name: j['name'] as String,
      sellingPrice: _asDouble(j['sellingPrice']),
      mrp: _asDouble(j['mrp']),
      imageUrl: firstUrl,
      ratingAvg: j['ratingAvg'] == null ? null : _asDouble(j['ratingAvg']),
      ratingCount: j['ratingCount'] as int? ?? 0,
    );
  }
}

class ContentBlock {
  const ContentBlock({required this.kind, required this.data});
  final String kind;
  final Map<String, dynamic> data;

  factory ContentBlock.fromJson(Map<String, dynamic> j) {
    final copy = Map<String, dynamic>.from(j);
    final kind = (copy.remove('kind') as String?) ?? 'TEXT';
    return ContentBlock(kind: kind, data: copy);
  }
}

class SpecGroup {
  const SpecGroup({required this.title, this.tab, required this.rows});
  final String title;
  final String? tab;
  final List<SpecRow> rows;

  factory SpecGroup.fromJson(Map<String, dynamic> j) {
    final tabRaw = (j['tab'] as String?)?.trim();
    return SpecGroup(
      title: (j['title'] as String?) ?? '',
      tab: tabRaw == null || tabRaw.isEmpty ? null : tabRaw,
      rows: ((j['rows'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SpecRow.fromJson)
          .where((r) => r.label.isNotEmpty)
          .toList(),
    );
  }
}

class SpecRow {
  const SpecRow({required this.label, required this.value});
  final String label;
  final String value;

  factory SpecRow.fromJson(Map<String, dynamic> j) => SpecRow(
        label: (j['label'] as String?) ?? '',
        value: (j['value'] as String?) ?? '',
      );
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

  factory ProductOffer.fromJson(Map<String, dynamic> j) => ProductOffer(
        kind: (j['kind'] as String?) ?? 'COUPON',
        headline: (j['headline'] as String?) ?? '',
        detail: j['detail'] as String?,
        code: j['code'] as String?,
      );
}

class ProductCategoryRef {
  const ProductCategoryRef({required this.id, required this.name, required this.slug});
  final String id;
  final String name;
  final String slug;
  factory ProductCategoryRef.fromJson(Map<String, dynamic> j) =>
      ProductCategoryRef(id: j['id'].toString(), name: j['name'] as String, slug: j['slug'] as String);
}
