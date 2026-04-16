import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/products/data/models/product_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductsRemoteDataSource {
  const ProductsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<({List<Product> products, int total})> getProducts({
    String? search,
    int? categoryId,
    bool? lowStock,
    int page = 1,
    int limit = 20,
    String sortBy = 'updatedAt',
    String sortOrder = 'desc',
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['categoryId'] = categoryId.toString();
    if (lowStock == true) params['lowStock'] = 'true';

    final response = await _client.get('/products', queryParameters: params);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    final pagination = body['pagination'] as Map<String, dynamic>;

    return (
      products: data
          .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: pagination['total'] as int,
    );
  }

  Future<Product> getProduct(int id) async {
    final response = await _client.get('/products/$id');
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Product?> lookupByCode(String code) async {
    final response = await _client.get(
      '/products/lookup',
      queryParameters: {'code': code},
    );
    if (response.statusCode == 404) return null;
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final response = await _client.post('/products', body: data);
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final response = await _client.patch('/products/$id', body: data);
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteProduct(int id) async {
    await _client.delete('/products/$id');
  }
}
