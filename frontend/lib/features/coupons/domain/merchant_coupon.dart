double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class MerchantCoupon {
  const MerchantCoupon({
    required this.id,
    required this.code,
    required this.title,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.validFrom,
    required this.validUntil,
    required this.perUserLimit,
    required this.totalCap,
    required this.totalRedemptions,
    required this.isPublic,
    required this.firstOrderOnly,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.maxDiscount,
  });

  final int id;
  final String code;
  final String title;
  final String? description;
  /// PERCENT or FLAT.
  final String discountType;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderAmount;
  final DateTime validFrom;
  final DateTime validUntil;
  final int perUserLimit;
  final int totalCap;
  final int totalRedemptions;
  /// Public coupons auto-apply at checkout and surface on the
  /// customer's coupon carousel. Private coupons (the default) are
  /// only redeemed by typing the code — useful for influencer drops,
  /// B2B deals, and refer-a-friend links.
  final bool isPublic;
  /// Only redeemable on the customer's first confirmed order.
  final bool firstOrderOnly;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isExpired => DateTime.now().isAfter(validUntil);
  bool get isExhausted => totalCap > 0 && totalRedemptions >= totalCap;

  factory MerchantCoupon.fromJson(Map<String, dynamic> j) {
    return MerchantCoupon(
      id: (j['id'] as num).toInt(),
      code: j['code'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      discountType: j['discountType'] as String,
      discountValue: _d(j['discountValue']),
      maxDiscount: j['maxDiscount'] != null ? _d(j['maxDiscount']) : null,
      minOrderAmount: _d(j['minOrderAmount']),
      validFrom: DateTime.parse(j['validFrom'] as String),
      validUntil: DateTime.parse(j['validUntil'] as String),
      perUserLimit: (j['perUserLimit'] as num).toInt(),
      totalCap: (j['totalCap'] as num).toInt(),
      totalRedemptions: (j['totalRedemptions'] as num).toInt(),
      isPublic: (j['isPublic'] as bool?) ?? false,
      firstOrderOnly: (j['firstOrderOnly'] as bool?) ?? false,
      isActive: j['isActive'] as bool,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}
