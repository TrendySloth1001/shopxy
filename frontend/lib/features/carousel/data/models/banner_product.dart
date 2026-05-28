/// Discount mode for a product pinned to a carousel slide. PERCENT
/// stores a 0..90 percent of sellingPrice; AMOUNT stores a flat rupee
/// discount per unit. The backend clamps merchant-typed values to a
/// safe range, so the client can trust whatever the API returns.
enum BannerProductDiscountType {
  percent,
  amount;

  String toWire() => this == percent ? 'PERCENT' : 'AMOUNT';

  static BannerProductDiscountType fromWire(String? v) {
    return v == 'AMOUNT' ? amount : percent;
  }
}

/// One row in a slide's curated product list. Mirrors the
/// /me/banners/:id/products payload — used both as the editor's
/// working model and as the wire shape on PUT replace.
///
/// The discount feeds invoice line discounts: when the merchant creates
/// an invoice for this product without typing a per-line discount, the
/// backend auto-stamps the carousel promo onto the line.
class BannerProductLink {
  const BannerProductLink({
    required this.productId,
    required this.name,
    required this.sku,
    required this.mrp,
    required this.sellingPrice,
    required this.imageUrl,
    required this.discountType,
    required this.discountValue,
    required this.position,
  });

  final int productId;
  final String name;
  final String sku;
  final double mrp;
  final double sellingPrice;
  final String imageUrl;
  final BannerProductDiscountType discountType;
  /// PERCENT: 0..90.  AMOUNT: rupees per unit, bounded to sellingPrice - 0.01.
  final double discountValue;
  final int position;

  /// Per-unit rupee discount derived from type+value. Used for ranking
  /// and for live preview in the editor. Mirrors backend
  /// `discountPerUnit` so the merchant sees the same number their books
  /// will record.
  double get perUnitDiscount {
    if (discountValue <= 0 || sellingPrice <= 0) return 0;
    if (discountType == BannerProductDiscountType.percent) {
      return _round2((sellingPrice * discountValue) / 100);
    }
    final double ceiling = sellingPrice > 0.01 ? sellingPrice - 0.01 : 0.0;
    return _round2(discountValue > ceiling ? ceiling : discountValue);
  }

  double get salePrice => _round2(sellingPrice - perUnitDiscount);

  factory BannerProductLink.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>;
    final images = (product['images'] as List?) ?? const [];
    // Legacy payloads send `discountPct: int` only. Map that to a
    // PERCENT/value pair so older API responses keep working through a
    // rollout window.
    final type = BannerProductDiscountType.fromWire(j['discountType'] as String?);
    final value = j['discountValue'] != null
        ? _asDouble(j['discountValue'])
        : _asDouble(j['discountPct']);
    return BannerProductLink(
      productId: (j['productId'] as num).toInt(),
      name: (product['name'] ?? '') as String,
      sku: (product['sku'] ?? '') as String,
      mrp: _asDouble(product['mrp']),
      sellingPrice: _asDouble(product['sellingPrice']),
      imageUrl: images.isNotEmpty
          ? (images.first as Map<String, dynamic>)['url'] as String? ?? ''
          : '',
      discountType: type,
      discountValue: value,
      position: (j['position'] as num?)?.toInt() ?? 0,
    );
  }

  BannerProductLink copyWith({
    BannerProductDiscountType? discountType,
    double? discountValue,
    int? position,
  }) {
    return BannerProductLink(
      productId: productId,
      name: name,
      sku: sku,
      mrp: mrp,
      sellingPrice: sellingPrice,
      imageUrl: imageUrl,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toReplaceItem(int idx) => {
        'productId': productId,
        'discountType': discountType.toWire(),
        'discountValue': discountValue,
        'position': idx,
      };

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static double _round2(double n) => (n * 100).roundToDouble() / 100;
}
