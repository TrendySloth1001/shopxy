import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/categories/data/models/category_dto.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';

class CategoriesRemoteDataSource {
  const CategoriesRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<CategoryNode>> getTree() async {
    final res = await _client.get(
      '/categories/tree',
      queryParameters: {'active': 'true'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load categories: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CategoryDto.treeNodeFromJson)
        .toList();
  }

  Future<({Category category, List<MarketplaceProduct> products, int total})>
      categoryProducts(
    String slug, {
    int page = 1,
    int limit = 24,
    String sort = 'popular',
  }) async {
    final res = await _client.get(
      '/marketplace/categories/$slug/products',
      queryParameters: {
        'page': '$page',
        'limit': '$limit',
        'sort': sort,
      },
    );
    if (res.statusCode == 404) throw Exception('Category not found');
    if (res.statusCode != 200) {
      throw Exception('Failed to load category: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final category =
        CategoryDto.fromJson(json['category'] as Map<String, dynamic>);
    final products = (json['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(MarketplaceProduct.fromJson)
        .toList();
    final total =
        (json['pagination'] as Map?)?['total'] as int? ?? products.length;
    return (category: category, products: products, total: total);
  }
}
