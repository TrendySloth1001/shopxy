import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_shop.dart';

/// Detail-level product as returned by `GET /marketplace/products/:id`.
/// Carries enough fields to render the V2 PDP: gallery, price/MRP +
/// derived discount, rating denorms, the owning shop, an optional
/// in-flight flash sale, and tags-as-highlights.
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
    this.ratingAvg,
    this.ratingCount = 0,
    this.shop,
    this.category,
    this.flashSale,
  });

  final int id;
  final String name;
  final String sku;
  final String unit;
  final double mrp;
  final double sellingPrice;
  final double taxPercent;
  final double stockQuantity;
  final List<String> images;
  final List<String> tags;

  /// Short above-the-fold bullets ("6.7-inch AMOLED", "7 years OS").
  /// Distinct from [tags] — those drive filtering; these drive
  /// presentation.
  final List<String> highlights;

  /// Long-form grouped spec sheet. Empty when the merchant hasn't
  /// filled one in; PDP collapses the section in that case.
  final List<SpecGroup> specs;

  /// Bank / coupon / EMI / exchange offers rendered beneath the
  /// price block.
  final List<ProductOffer> offers;
  final int totalSold;
  final String? description;
  final double? ratingAvg;
  final int ratingCount;
  final MarketplaceShop? shop;
  final ProductCategoryRef? category;
  final ActiveFlashSale? flashSale;

  bool get inStock => stockQuantity > 0;
  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;
  int get discountPct {
    if (mrp <= 0 || sellingPrice <= 0 || mrp <= sellingPrice) return 0;
    return (((mrp - sellingPrice) / mrp) * 100).round();
  }

  double get effectivePrice => flashSale?.price ?? sellingPrice;

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
    final flashList = j['flashSales'] as List<dynamic>? ?? [];
    final specRaw = j['specs'];
    final offersRaw = j['offers'];
    return MarketplaceProduct(
      id: j['id'] as int,
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
      ratingAvg: j['ratingAvg'] == null ? null : _asDouble(j['ratingAvg']),
      ratingCount: j['ratingCount'] as int? ?? 0,
      shop: j['shop'] is Map<String, dynamic>
          ? MarketplaceShop.fromJson(j['shop'] as Map<String, dynamic>)
          : null,
      category: j['category'] is Map<String, dynamic>
          ? ProductCategoryRef.fromJson(j['category'] as Map<String, dynamic>)
          : null,
      flashSale: flashList.isEmpty
          ? null
          : ActiveFlashSale.fromJson(flashList.first as Map<String, dynamic>),
    );
  }
}

/// One section of the spec sheet — title plus N (label, value) rows.
class SpecGroup {
  const SpecGroup({required this.title, required this.rows});
  final String title;
  final List<SpecRow> rows;

  factory SpecGroup.fromJson(Map<String, dynamic> j) => SpecGroup(
        title: (j['title'] as String?) ?? '',
        rows: ((j['rows'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SpecRow.fromJson)
            .where((r) => r.label.isNotEmpty)
            .toList(),
      );
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

/// A single bank / coupon / EMI / exchange offer.
class ProductOffer {
  const ProductOffer({
    required this.kind,
    required this.headline,
    this.detail,
    this.code,
  });

  /// 'BANK' | 'COUPON' | 'EMI' | 'EXCHANGE' — kept as a String so the
  /// customer model survives new server-side kinds without a client
  /// release. The PDP falls back to a generic icon for unknown kinds.
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
  final int id;
  final String name;
  final String slug;
  factory ProductCategoryRef.fromJson(Map<String, dynamic> j) =>
      ProductCategoryRef(id: j['id'] as int, name: j['name'] as String, slug: j['slug'] as String);
}

class ActiveFlashSale {
  const ActiveFlashSale({
    required this.id,
    required this.price,
    required this.stockLimit,
    required this.soldCount,
    required this.endAt,
  });
  final int id;
  final double price;
  final int stockLimit;
  final int soldCount;
  final DateTime endAt;

  double get soldPct =>
      stockLimit <= 0 ? 0 : (soldCount / stockLimit).clamp(0.0, 1.0).toDouble();
  int get remaining => (stockLimit - soldCount).clamp(0, stockLimit).toInt();

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory ActiveFlashSale.fromJson(Map<String, dynamic> j) {
    return ActiveFlashSale(
      id: j['id'] as int,
      price: _asDouble(j['flashPrice']),
      stockLimit: j['stockLimit'] as int? ?? 0,
      soldCount: j['soldCount'] as int? ?? 0,
      endAt: DateTime.parse(j['endAt'] as String),
    );
  }
}
