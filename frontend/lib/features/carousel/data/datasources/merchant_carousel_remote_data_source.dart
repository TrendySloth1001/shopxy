import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/data/models/banner_product.dart';

/// Talks to /me/banners — the merchant-scoped CRUD endpoints that
/// share the platform Banner table but auto-stamp `sponsorShopId`
/// from the caller's resolved shop. Returns the same `AdminBanner`
/// shape the admin tooling uses so the editor UI can be shared.
class MerchantCarouselRemoteDataSource {
  MerchantCarouselRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<AdminBanner>> list() async {
    final res = await _client.get('/me/banners');
    if (res.statusCode != 200) {
      throw Exception('Failed to load carousel: ${res.body}');
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

  /// Returns the products linked to a slide, in display order, with
  /// per-row discount percent. Used to hydrate the editor when the
  /// merchant opens an existing slide.
  Future<List<BannerProductLink>> listProducts(int bannerId) async {
    final res = await _client.get('/me/banners/$bannerId/products');
    if (res.statusCode != 200) {
      throw Exception('Failed to load slide products: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => BannerProductLink.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Full-list replace — sends every link; rows the server doesn't see
  /// are removed. Matches the backend's PUT replace semantics.
  Future<List<BannerProductLink>> replaceProducts(
    int bannerId,
    List<BannerProductLink> items,
  ) async {
    final body = {
      'items': [
        for (int i = 0; i < items.length; i++) items[i].toReplaceItem(i),
      ],
    };
    final res = await _client.put('/me/banners/$bannerId/products', body: body);
    if (res.statusCode != 200) {
      throw Exception('Save linked products failed: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List<dynamic>)
        .map((e) => BannerProductLink.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
