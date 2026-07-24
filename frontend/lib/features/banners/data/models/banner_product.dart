/// Discount mode for a banner-pinned product.
///   * percent — N% off the product's selling price (0..90)
///   * amount  — flat rupees off per unit
enum BannerDiscountType { percent, amount }

extension BannerDiscountTypeX on BannerDiscountType {
  String get wire {
    switch (this) {
      case BannerDiscountType.percent:
        return 'PERCENT';
      case BannerDiscountType.amount:
        return 'AMOUNT';
    }
  }

  String get label {
    switch (this) {
      case BannerDiscountType.percent:
        return '% off';
      case BannerDiscountType.amount:
        return '₹ off';
    }
  }
}

BannerDiscountType bannerDiscountTypeFromWire(String? s) {
  switch (s) {
    case 'AMOUNT':
      return BannerDiscountType.amount;
    case 'PERCENT':
    default:
      return BannerDiscountType.percent;
  }
}

/// Slim product summary embedded in a banner-product row.
class BannerProductSummary {
  const BannerProductSummary({
    required this.id,
    required this.name,
    required this.sku,
    required this.mrp,
    required this.sellingPrice,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String sku;
  final double mrp;
  final double sellingPrice;
  final String? imageUrl;

  factory BannerProductSummary.fromJson(Map<String, dynamic> j) {
    final imgs = (j['images'] as List<dynamic>?) ?? const [];
    String? first;
    if (imgs.isNotEmpty) {
      final sorted = imgs.whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) =>
            ((a['sortOrder'] as int?) ?? 0).compareTo((b['sortOrder'] as int?) ?? 0));
      if (sorted.isNotEmpty) first = sorted.first['url'] as String?;
    }
    return BannerProductSummary(
      id: j['id'].toString(),
      name: j['name'] as String,
      sku: j['sku'] as String,
      mrp: _toDouble(j['mrp']),
      sellingPrice: _toDouble(j['sellingPrice']),
      imageUrl: first,
    );
  }
}

/// One curated product pinned to a banner, with its per-product discount
/// and the server-computed sale price.
class BannerProductRow {
  const BannerProductRow({
    required this.id,
    required this.productId,
    required this.position,
    required this.discountType,
    required this.discountValue,
    required this.salePrice,
    required this.perUnitDiscount,
    required this.product,
  });

  final String id;
  final String productId;
  final int position;
  final BannerDiscountType discountType;
  final double discountValue;
  final double salePrice;
  final double perUnitDiscount;
  final BannerProductSummary product;

  factory BannerProductRow.fromJson(Map<String, dynamic> j) => BannerProductRow(
        id: (j['id']?.toString()) ?? '',
        productId: j['productId'].toString(),
        position: (j['position'] as int?) ?? 0,
        discountType: bannerDiscountTypeFromWire(j['discountType'] as String?),
        discountValue: _toDouble(j['discountValue']),
        salePrice: _toDouble(j['salePrice']),
        perUnitDiscount: _toDouble(j['perUnitDiscount']),
        product:
            BannerProductSummary.fromJson(j['product'] as Map<String, dynamic>),
      );
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
