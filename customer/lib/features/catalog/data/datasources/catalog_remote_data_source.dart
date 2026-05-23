import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';

class CatalogRemoteDataSource {
  const CatalogRemoteDataSource(this._client);
  final ApiClient _client;

  Future<({List<CatalogProduct> data, int total})> listProducts({
    String search = '',
    int? categoryId,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _client.get('/me/catalog/products', queryParameters: {
      'page': '$page',
      'limit': '$limit',
      if (search.isNotEmpty) 'search': search,
      if (categoryId != null) 'categoryId': '$categoryId',
    });
    if (res.statusCode != 200) {
      throw Exception('Failed to load catalog: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (json['data'] as List)
        .map((e) => CatalogProduct.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (json['pagination'] as Map?)?['total'] as int? ?? list.length;
    return (data: list, total: total);
  }

  Future<CatalogProduct> product(int id) async {
    final res = await _client.get('/me/catalog/products/$id');
    if (res.statusCode != 200) throw Exception('Product not found');
    return CatalogProduct.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<CatalogCategory>> categories() async {
    final res = await _client.get('/me/catalog/categories');
    if (res.statusCode != 200) {
      throw Exception('Failed to load categories: ${res.statusCode}');
    }
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => CatalogCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
