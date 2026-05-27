import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/coupons/domain/merchant_coupon.dart';

/// Adapter for the merchant-side coupon admin endpoints under
/// `/me/coupons-admin`. (Customer-facing `/me/coupons` is a separate
/// surface that the customer app — not the merchant — talks to.)
class MerchantCouponsRemoteDataSource {
  const MerchantCouponsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<MerchantCoupon>> list() async {
    final res = await _client.get('/me/coupons-admin');
    if (res.statusCode != 200) {
      throw Exception('Failed to load coupons (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return ((json['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MerchantCoupon.fromJson)
        .toList();
  }

  Future<int> create({
    required String code,
    required String title,
    String? description,
    required String discountType,
    required double discountValue,
    double? maxDiscount,
    double minOrderAmount = 0,
    required DateTime validFrom,
    required DateTime validUntil,
    int perUserLimit = 1,
    int totalCap = 0,
    bool isPublic = false,
    bool firstOrderOnly = false,
    bool isActive = true,
  }) async {
    final res = await _client.post('/me/coupons-admin', body: {
      'code': code,
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      if (maxDiscount != null) 'maxDiscount': maxDiscount,
      'minOrderAmount': minOrderAmount,
      'validFrom': validFrom.toUtc().toIso8601String(),
      'validUntil': validUntil.toUtc().toIso8601String(),
      'perUserLimit': perUserLimit,
      'totalCap': totalCap,
      'isPublic': isPublic,
      'firstOrderOnly': firstOrderOnly,
      'isActive': isActive,
    });
    if (res.statusCode == 201) {
      return (jsonDecode(res.body)['id'] as num).toInt();
    }
    throw Exception(_decodeError(res.body));
  }

  Future<void> update(
    int id, {
    String? code,
    String? title,
    String? description,
    String? discountType,
    double? discountValue,
    double? maxDiscount,
    double? minOrderAmount,
    DateTime? validFrom,
    DateTime? validUntil,
    int? perUserLimit,
    int? totalCap,
    bool? isPublic,
    bool? firstOrderOnly,
    bool? isActive,
  }) async {
    final res = await _client.patch('/me/coupons-admin/$id', body: {
      if (code != null) 'code': code,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (discountType != null) 'discountType': discountType,
      if (discountValue != null) 'discountValue': discountValue,
      if (maxDiscount != null) 'maxDiscount': maxDiscount,
      if (minOrderAmount != null) 'minOrderAmount': minOrderAmount,
      if (validFrom != null) 'validFrom': validFrom.toUtc().toIso8601String(),
      if (validUntil != null)
        'validUntil': validUntil.toUtc().toIso8601String(),
      if (perUserLimit != null) 'perUserLimit': perUserLimit,
      if (totalCap != null) 'totalCap': totalCap,
      if (isPublic != null) 'isPublic': isPublic,
      if (firstOrderOnly != null) 'firstOrderOnly': firstOrderOnly,
      if (isActive != null) 'isActive': isActive,
    });
    if (res.statusCode == 204) return;
    throw Exception(_decodeError(res.body));
  }

  Future<void> deactivate(int id) async {
    final res = await _client.delete('/me/coupons-admin/$id');
    if (res.statusCode == 204) return;
    throw Exception(_decodeError(res.body));
  }

  String _decodeError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      final code = (m['error'] as String?) ?? 'Request failed';
      switch (code) {
        case 'CODE_TAKEN':
          return 'That coupon code is already in use.';
        case 'BAD_DATES':
          return 'Valid-from must be earlier than valid-until.';
        case 'BAD_VALUE':
          return 'Discount value is invalid.';
        case 'NOT_FOUND':
          return 'Coupon not found.';
        default:
          return code;
      }
    } catch (_) {
      return 'Request failed';
    }
  }
}
