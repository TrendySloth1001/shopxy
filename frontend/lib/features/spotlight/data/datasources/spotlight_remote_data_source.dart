import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/spotlight/data/models/spotlight.dart';

class SpotlightRemoteDataSource {
  SpotlightRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<Spotlight>> list() async {
    final res = await _client.get('/me/brand-spotlight');
    if (res.statusCode != 200) {
      throw Exception('Failed to load spotlights: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => Spotlight.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Spotlight> submit(Map<String, dynamic> body) async {
    final res = await _client.post('/me/brand-spotlight/request', body: body);
    if (res.statusCode != 201) {
      throw Exception('Submit failed: ${res.body}');
    }
    return Spotlight.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> cancel(int id) async {
    final res = await _client.delete('/me/brand-spotlight/$id');
    if (res.statusCode != 204) {
      throw Exception('Cancel failed (status ${res.statusCode}): ${res.body}');
    }
  }
}
