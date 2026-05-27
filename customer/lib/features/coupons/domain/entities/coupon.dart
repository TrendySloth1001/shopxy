double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class CouponShop {
  const CouponShop({required this.id, required this.name, required this.slug});
  final int id;
  final String name;
  final String slug;
  factory CouponShop.fromJson(Map<String, dynamic> j) => CouponShop(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? '',
        slug: (j['slug'] as String?) ?? '',
      );
}

/// A redeemable coupon as surfaced on the "My coupons" page.
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

  final int id;
  final String code;
  final String title;
  final String? description;
  /// PERCENT or FLAT.
  final String discountType;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderAmount;
  final DateTime validUntil;
  /// Platform-wide coupons have a null shop.
  final CouponShop? shop;
  /// True when the per-user redemption limit has already been hit. The
  /// card stays on the list (with a "Used" badge) so the customer
  /// knows the coupon exists but is no longer redeemable for them.
  final bool exhausted;
  /// Public coupons auto-apply on checkout — no manual code entry.
  /// Private coupons (default) require typing the code.
  final bool isPublic;
  /// Restricted to first-time customers. Surfaces a "First order only"
  /// pill on the card.
  final bool firstOrderOnly;

  /// "10% off (max ₹200)" / "Flat ₹100 off"
  String get headline {
    if (discountType == 'PERCENT') {
      final pct = discountValue == discountValue.roundToDouble()
          ? discountValue.toStringAsFixed(0)
          : discountValue.toStringAsFixed(1);
      if (maxDiscount != null) {
        return '$pct% off · up to ₹${maxDiscount!.toStringAsFixed(0)}';
      }
      return '$pct% off';
    }
    return 'Flat ₹${discountValue.toStringAsFixed(0)} off';
  }

  /// "Min cart ₹X" subtitle — empty when the coupon has no minimum.
  String get minOrderLabel =>
      minOrderAmount > 0 ? 'Min cart ₹${minOrderAmount.toStringAsFixed(0)}' : '';

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        id: j['id'] as int,
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

/// Result of `POST /me/coupons/validate` and `…/auto-apply` — either
/// an `ok: true` row carrying the effective discount or an `ok: false`
/// row with a human-readable reason. `autoApplied` is true when the
/// coupon came from the auto-apply endpoint (a public coupon picked
/// for the customer without a code entry); UI uses it to show the
/// "Auto-applied" badge instead of the manual chip.
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
  final int? couponId;
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
        couponId: c['id'] as int,
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
