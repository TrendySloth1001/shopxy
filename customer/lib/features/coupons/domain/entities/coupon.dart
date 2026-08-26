import 'package:shopxy_customer/shared/format/app_format.dart';

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class CouponShop {
  const CouponShop({required this.id, required this.name, required this.slug});
  final String id;
  final String name;
  final String slug;
  factory CouponShop.fromJson(Map<String, dynamic> j) => CouponShop(
        id: j['id'].toString(),
        name: (j['name'] as String?) ?? '',
        slug: (j['slug'] as String?) ?? '',
      );
}

class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.title,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.validUntil,
    required this.exhausted,
    required this.isPublic,
    required this.firstOrderOnly,
    this.description,
    this.maxDiscount,
    this.shop,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final String discountType;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderAmount;
  final DateTime validUntil;
  final CouponShop? shop;
  final bool exhausted;
  final bool isPublic;
  final bool firstOrderOnly;

  String get headline {
    if (discountType == 'PERCENT') {
      final pct = discountValue == discountValue.roundToDouble()
          ? discountValue.toStringAsFixed(0)
          : discountValue.toStringAsFixed(1);
      if (maxDiscount != null) {
        return '$pct% off · up to ${AppFormat.rupees(maxDiscount!)}';
      }
      return '$pct% off';
    }
    return 'Flat ${AppFormat.rupees(discountValue)} off';
  }

  String get minOrderLabel =>
      minOrderAmount > 0 ? 'Min cart ${AppFormat.rupees(minOrderAmount)}' : '';

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        id: j['id'].toString(),
        code: j['code'] as String,
        title: (j['title'] as String?) ?? '',
        description: j['description'] as String?,
        discountType: j['discountType'] as String,
        discountValue: _d(j['discountValue']),
        maxDiscount:
            j['maxDiscount'] == null ? null : _d(j['maxDiscount']),
        minOrderAmount: _d(j['minOrderAmount']),
        validUntil: DateTime.parse(j['validUntil'] as String),
        exhausted: (j['exhausted'] as bool?) ?? false,
        isPublic: (j['isPublic'] as bool?) ?? false,
        firstOrderOnly: (j['firstOrderOnly'] as bool?) ?? false,
        shop: j['shop'] == null
            ? null
            : CouponShop.fromJson(j['shop'] as Map<String, dynamic>),
      );
}

class CouponPreview {
  const CouponPreview({
    required this.ok,
    this.couponId,
    this.code,
    this.title,
    this.discountType,
    this.discount,
    this.errorCode,
    this.message,
    this.autoApplied = false,
    this.firstOrderOnly = false,
  });

  final bool ok;
  final String? couponId;
  final String? code;
  final String? title;
  final String? discountType;
  final double? discount;
  final String? errorCode;
  final String? message;
  final bool autoApplied;
  final bool firstOrderOnly;

  CouponPreview copyWith({bool? autoApplied}) => CouponPreview(
        ok: ok,
        couponId: couponId,
        code: code,
        title: title,
        discountType: discountType,
        discount: discount,
        errorCode: errorCode,
        message: message,
        autoApplied: autoApplied ?? this.autoApplied,
        firstOrderOnly: firstOrderOnly,
      );

  factory CouponPreview.fromJson(Map<String, dynamic> j) {
    if (j['ok'] == true) {
      final c = j['coupon'] as Map<String, dynamic>;
      return CouponPreview(
        ok: true,
        couponId: c['id'].toString(),
        code: c['code'] as String,
        title: c['title'] as String,
        discountType: c['discountType'] as String,
        discount: _d(c['discount']),
        firstOrderOnly: (c['firstOrderOnly'] as bool?) ?? false,
      );
    }
    return CouponPreview(
      ok: false,
      errorCode: j['code'] as String?,
      message: j['message'] as String?,
    );
  }
}
