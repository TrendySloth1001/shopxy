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
