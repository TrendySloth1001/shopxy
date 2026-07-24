import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/coupons/domain/entities/coupon.dart';

class CouponsRemoteDataSource {
  const CouponsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<Coupon>> listAvailable() async {
    final res = await _client.get('/me/coupons');
    if (res.statusCode != 200) {
      throw Exception('Failed to load coupons (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return ((json['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Coupon.fromJson)
        .toList();
  }

  /// Preview a coupon against a cart context. Returns a [CouponPreview]
  /// regardless of validity — `ok=false` carries the reason.
  Future<CouponPreview> validate({
    required String code,
    required double subtotal,
    required List<String> shopIds,
  }) async {
    final res = await _client.post(
      '/me/coupons/validate',
      body: {
        'code': code,
        'subtotal': subtotal,
        'shopIds': shopIds,
      },
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return CouponPreview.fromJson(json);
  }

  /// Ask the server for the best PUBLIC coupon that applies to the
  /// current cart. Returns a preview with `autoApplied = true` when
  /// one matches, or `ok = false` when nothing does. The checkout
  /// page pre-applies the result so customers don't have to type a
  /// code that's already on their carousel.
  Future<CouponPreview> autoApply({
    required double subtotal,
    required List<String> shopIds,
  }) async {
    final res = await _client.post(
      '/me/coupons/auto-apply',
      body: {
        'subtotal': subtotal,
        'shopIds': shopIds,
      },
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final preview = CouponPreview.fromJson(json);
    return preview.ok ? preview.copyWith(autoApplied: true) : preview;
  }
}
