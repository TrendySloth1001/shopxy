import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_shop.dart';

class MarketplaceRemoteDataSource {
  const MarketplaceRemoteDataSource(this._client);
  final ApiClient _client;

  Future<MarketplaceProduct> product(String id) async {
    final res = await _client.get('/marketplace/products/$id');
    if (res.statusCode == 404) {
      throw Exception('Product not found');
    }
    if (res.statusCode != 200) {
      throw Exception('Failed to load product: ${res.statusCode}');
    }
    return MarketplaceProduct.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<List<MarketplaceFbtCard>> frequentlyBoughtTogether(String productId) async {
    final res = await _client.get(
      '/marketplace/products/$productId/frequently-bought-together',
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load FBT: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List<dynamic>)
        .map((e) => MarketplaceFbtCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({MarketplaceShop shop, List<MarketplaceProduct> products, int total})>
      shopProducts(
    String slug, {
    int page = 1,
    int limit = 24,
    String sort = 'popular',
  }) async {
    final res = await _client.get(
      '/marketplace/shops/$slug/products',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        'sort': sort,
      },
    );
    if (res.statusCode == 404) throw Exception('Shop not found');
    if (res.statusCode != 200) {
      throw Exception('Failed to load shop: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final shop = MarketplaceShop.fromJson(json['shop'] as Map<String, dynamic>);
    final products = (json['data'] as List<dynamic>)
        .map((e) => MarketplaceProduct.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (json['pagination'] as Map?)?['total'] as int? ?? products.length;
    return (shop: shop, products: products, total: total);
  }
}
