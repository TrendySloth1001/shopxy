class BannerDetail {
  const BannerDetail({
    required this.banner,
    required this.products,
  });

  final BannerHeader banner;
  final List<BannerProduct> products;

  factory BannerDetail.fromJson(Map<String, dynamic> json) {
    final banner = json['banner'] as Map<String, dynamic>;
    final products = (json['products'] as List?) ?? const [];
    return BannerDetail(
      banner: BannerHeader.fromJson(banner),
      products: products
          .whereType<Map<String, dynamic>>()
          .map(BannerProduct.fromJson)
          .toList(),
    );
  }
}

class BannerHeader {
  const BannerHeader({
    required this.id,
    required this.imageUrl,
    required this.productCount,
    this.placement,
    this.linkUrl,
    this.sortOrder = 0,
  });

  final String id;

  final String imageUrl;
  final int productCount;
  final String? placement;
  final String? linkUrl;
  final int sortOrder;

  factory BannerHeader.fromJson(Map<String, dynamic> json) {
    return BannerHeader(
      id: json['id'].toString(),
      imageUrl: (json['imageUrl'] ?? '') as String,
      productCount: _asInt(json['productCount']) ?? 0,
      placement: json['placement'] as String?,
      linkUrl: (json['linkUrl'] as String?)?.trim().isEmpty == false
          ? (json['linkUrl'] as String).trim()
          : null,
      sortOrder: _asInt(json['sortOrder']) ?? 0,
    );
  }
}

class BannerProduct {
  const BannerProduct({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.salePrice,
    required this.discountPct,
    required this.imageUrl,
    required this.rating,
    required this.ratingCount,
    this.mrp,
    this.brand,
    this.shopName,
    this.shopSlug,
  });

  final String id;
  final String name;

  final double sellingPrice;

  final double salePrice;

  final int discountPct;

  final String imageUrl;
  final double rating;
  final int ratingCount;
  final double? mrp;
  final String? brand;
  final String? shopName;
  final String? shopSlug;

  bool get hasDiscount => salePrice < sellingPrice;

  factory BannerProduct.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] as Map<String, dynamic>?;
    final selling = _asDouble(json['sellingPrice']) ?? 0;
    return BannerProduct(
      id: json['id'].toString(),
      name: (json['name'] ?? '') as String,
      sellingPrice: selling,
      salePrice: _asDouble(json['salePrice']) ?? selling,
      discountPct: _asInt(json['discountPct']) ?? 0,
      imageUrl: _firstImage(json),
      rating: _asDouble(json['ratingAvg']) ?? 0,
      ratingCount: _asInt(json['ratingCount']) ?? 0,
      mrp: _asDouble(json['mrp']),
      brand: json['brand'] as String?,
      shopName: shop?['name'] as String?,
      shopSlug: shop?['slug'] as String?,
    );
  }
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String _firstImage(Map<String, dynamic> product) {
  final imgs = product['images'];
  if (imgs is List && imgs.isNotEmpty) {
    final first = imgs.first;
    if (first is Map<String, dynamic>) return (first['url'] ?? '') as String;
  }
  return '';
}
