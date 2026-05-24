import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/admin/data/models/admin_spotlight.dart';
import 'package:shopxy/features/spotlight/data/models/spotlight.dart';

class AdminSpotlightRemoteDataSource {
  AdminSpotlightRemoteDataSource(this._client);
  final ApiClient _client;

  Future<AdminSpotlightsPage> list({
    SpotlightStatus? status,
    int? cursor,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (status != null) query['status'] = status.wire;
    if (cursor != null) query['cursor'] = '$cursor';
    final res = await _client.get('/admin/brand-spotlight', queryParameters: query);
    if (res.statusCode != 200) {
      throw Exception('Failed to load spotlights: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>)
        .map((e) => AdminSpotlight.fromJson(e as Map<String, dynamic>))
        .toList();
    return AdminSpotlightsPage(
      data: data,
      nextCursor: body['nextCursor'] as int?,
    );
  }

  Future<AdminSpotlight> approve(int id) async {
    final res = await _client.patch('/admin/brand-spotlight/$id/approve', body: {});
    if (res.statusCode != 200) {
      throw Exception('Approve failed: ${res.body}');
    }
    return AdminSpotlight.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AdminSpotlight> reject(int id, String reason) async {
    final res = await _client.patch(
      '/admin/brand-spotlight/$id/reject',
      body: {'reason': reason},
    );
    if (res.statusCode != 200) {
      throw Exception('Reject failed: ${res.body}');
    }
    return AdminSpotlight.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
