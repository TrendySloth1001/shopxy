import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';

class AdminBannersRemoteDataSource {
  AdminBannersRemoteDataSource(this._client);
  final ApiClient _client;

  Future<AdminBannersPage> list({
    BannerPlacement? placement,
    int? cursor,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (placement != null) query['placement'] = placement.wire;
    if (cursor != null) query['cursor'] = '$cursor';
    final res = await _client.get('/admin/banners', queryParameters: query);
    if (res.statusCode != 200) {
      throw Exception('Failed to load banners: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>)
        .map((e) => AdminBanner.fromJson(e as Map<String, dynamic>))
        .toList();
    return AdminBannersPage(
      data: data,
      nextCursor: body['nextCursor'] as int?,
    );
  }

  Future<AdminBanner> create(Map<String, dynamic> body) async {
    final res = await _client.post('/admin/banners', body: body);
    if (res.statusCode != 201) {
      throw Exception('Create failed: ${res.body}');
    }
    return AdminBanner.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AdminBanner> update(int id, Map<String, dynamic> body) async {
    final res = await _client.patch('/admin/banners/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.body}');
    }
    return AdminBanner.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await _client.delete('/admin/banners/$id');
    if (res.statusCode != 204) {
      throw Exception('Delete failed: ${res.body}');
    }
  }
}
