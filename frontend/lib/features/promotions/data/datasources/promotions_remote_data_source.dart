import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/promotions/data/models/promotion.dart';

class PromotionsRemoteDataSource {
  PromotionsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<Promotion>> list() async {
    final res = await _client.get('/me/promotions');
    if (res.statusCode != 200) {
      throw Exception('Failed to load promotions: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => Promotion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Promotion> create(Map<String, dynamic> body) async {
    final res = await _client.post('/me/promotions', body: body);
    if (res.statusCode != 201) {
      throw Exception('Create failed: ${res.body}');
    }
    return Promotion.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Promotion> update(int id, Map<String, dynamic> body) async {
    final res = await _client.patch('/me/promotions/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.body}');
    }
    return Promotion.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> cancel(int id) async {
    final res = await _client.delete('/me/promotions/$id');
    if (res.statusCode != 204) {
      throw Exception('Cancel failed: ${res.body}');
    }
  }
}
