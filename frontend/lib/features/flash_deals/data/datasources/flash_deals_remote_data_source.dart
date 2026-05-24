import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/flash_deals/data/models/flash_deal.dart';

class FlashDealsRemoteDataSource {
  FlashDealsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<FlashDeal>> list({FlashDealStatus? status}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status.wire;
    final res = await _client.get('/me/flash-deals', queryParameters: query);
    if (res.statusCode != 200) {
      throw Exception('Failed to load flash deals: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => FlashDeal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FlashDeal> create({
    required int productId,
    required double flashPrice,
    required int stockLimit,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final res = await _client.post('/me/flash-deals', body: {
      'productId': productId,
      'flashPrice': flashPrice,
      'stockLimit': stockLimit,
      'startAt': startAt.toUtc().toIso8601String(),
      'endAt': endAt.toUtc().toIso8601String(),
    });
    if (res.statusCode != 201) {
      throw FlashDealApiException(res.statusCode, res.body);
    }
    return FlashDeal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<FlashDeal> update(int id, Map<String, dynamic> body) async {
    final res = await _client.patch('/me/flash-deals/$id', body: body);
    if (res.statusCode != 200) {
      throw FlashDealApiException(res.statusCode, res.body);
    }
    return FlashDeal.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> cancel(int id) async {
    final res = await _client.delete('/me/flash-deals/$id');
    if (res.statusCode != 204) {
      throw FlashDealApiException(res.statusCode, res.body);
    }
  }
}

/// Lightweight exception class so the editor sheet can pull a friendly
/// message out of the backend's structured error payload instead of
/// showing the raw HTTP body.
class FlashDealApiException implements Exception {
  FlashDealApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  String get friendlyMessage {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final err = j['error'] as String?;
      if (err != null) return err;
    } catch (_) {}
    return body;
  }

  @override
  String toString() => 'FlashDealApiException($statusCode): $body';
}
