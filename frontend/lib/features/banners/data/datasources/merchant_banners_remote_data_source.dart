import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';

/// Merchant-side banner CRUD against the slim `/me/banners` API. Reuses
/// the slim [AdminBanner]/[BannerPlacement] model — the wire shape is
/// identical to the admin endpoint.
class MerchantBannersRemoteDataSource {
  MerchantBannersRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<AdminBanner>> list() async {
    final res = await _client.get('/me/banners');
    if (res.statusCode != 200) {
      throw Exception('Failed to load banners: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => AdminBanner.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminBanner> create(Map<String, dynamic> body) async {
    final res = await _client.post('/me/banners', body: body);
    if (res.statusCode != 201) {
      throw Exception('Create failed: ${res.body}');
    }
    return AdminBanner.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AdminBanner> update(int id, Map<String, dynamic> body) async {
    final res = await _client.patch('/me/banners/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.body}');
    }
    return AdminBanner.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await _client.delete('/me/banners/$id');
    if (res.statusCode != 204) {
      throw Exception('Delete failed: ${res.body}');
    }
  }
}
