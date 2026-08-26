import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/banners/data/models/banner_product.dart';

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

  Future<AdminBanner> update(String id, Map<String, dynamic> body) async {
    final res = await _client.patch('/me/banners/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.body}');
    }
    return AdminBanner.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    final res = await _client.delete('/me/banners/$id');
    if (res.statusCode != 204) {
      throw Exception('Delete failed: ${res.body}');
    }
  }

  Future<List<BannerProductRow>> listBannerProducts(String bannerId) async {
    final res = await _client.get('/me/banners/$bannerId/products');
    if (res.statusCode != 200) {
      throw Exception('Failed to load banner products: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => BannerProductRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BannerProductRow>> replaceBannerProducts(
    String bannerId,
    List<BannerProductInput> items,
  ) async {
    final res = await _client.put(
      '/me/banners/$bannerId/products',
      body: {
        'items': items
            .map((i) => {
                  'productId': i.productId,
                  'discountType': i.discountType.wire,
                  'discountValue': i.discountValue,
                  'position': i.position,
                })
            .toList(),
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Replace banner products failed: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => BannerProductRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class BannerProductInput {
  const BannerProductInput({
    required this.productId,
    required this.discountType,
    required this.discountValue,
    required this.position,
  });

  final String productId;
  final BannerDiscountType discountType;
  final double discountValue;
  final int position;
}
