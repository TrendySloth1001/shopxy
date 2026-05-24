/// One row in a slide's curated product list. Mirrors the
/// /me/banners/:id/products payload — used both as the editor's
/// working model and as the wire shape on PUT replace.
class BannerProductLink {
  const BannerProductLink({
    required this.productId,
    required this.name,
    required this.sku,
    required this.mrp,
    required this.sellingPrice,
    required this.imageUrl,
    required this.discountPct,
    required this.position,
  });

  final int productId;
  final String name;
  final String sku;
  final double mrp;
  final double sellingPrice;
  final String imageUrl;
  final int discountPct;
  final int position;

  /// Sale price computed on the client to mirror what the customer-side
  /// slide page will show — used in the editor row preview so the
  /// merchant sees the same number their buyer will.
  double get salePrice => sellingPrice * (1 - discountPct / 100);

  factory BannerProductLink.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>;
    final images = (product['images'] as List?) ?? const [];
    return BannerProductLink(
      productId: (j['productId'] as num).toInt(),
      name: (product['name'] ?? '') as String,
      sku: (product['sku'] ?? '') as String,
      mrp: _asDouble(product['mrp']),
      sellingPrice: _asDouble(product['sellingPrice']),
      imageUrl: images.isNotEmpty
          ? (images.first as Map<String, dynamic>)['url'] as String? ?? ''
          : '',
      discountPct: (j['discountPct'] as num?)?.toInt() ?? 0,
      position: (j['position'] as num?)?.toInt() ?? 0,
    );
  }

  BannerProductLink copyWith({int? discountPct, int? position}) {
    return BannerProductLink(
      productId: productId,
      name: name,
      sku: sku,
      mrp: mrp,
      sellingPrice: sellingPrice,
      imageUrl: imageUrl,
      discountPct: discountPct ?? this.discountPct,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toReplaceItem(int idx) => {
        'productId': productId,
        'discountPct': discountPct,
        'position': idx,
      };

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
