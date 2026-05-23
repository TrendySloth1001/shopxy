import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';

class WishlistEntry {
  WishlistEntry({
    required this.id,
    required this.savedAt,
    required this.product,
  });
  final int id;
  final DateTime savedAt;
  final CatalogProduct product;

  factory WishlistEntry.fromJson(Map<String, dynamic> j) {
    return WishlistEntry(
      id: j['id'] as int,
      savedAt: DateTime.parse(j['savedAt'] as String),
      product: CatalogProduct.fromJson(j['product'] as Map<String, dynamic>),
    );
  }
}

class WishlistRemoteDataSource {
  const WishlistRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<WishlistEntry>> list() async {
    final res = await _client.get('/me/wishlist');
    if (res.statusCode != 200) {
      throw Exception('Failed to load wishlist: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (json['data'] as List<dynamic>);
    return data
        .map((e) => WishlistEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(int productId) async {
    final res = await _client.post('/me/wishlist/$productId');
    if (res.statusCode != 204) {
      final body = res.body.isEmpty
          ? null
          : jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body?['error'] ?? 'Failed to add to wishlist');
    }
  }

  Future<void> remove(int productId) async {
    final res = await _client.delete('/me/wishlist/$productId');
    if (res.statusCode != 204) {
      final body = res.body.isEmpty
          ? null
          : jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body?['error'] ?? 'Failed to remove from wishlist');
    }
  }
}
