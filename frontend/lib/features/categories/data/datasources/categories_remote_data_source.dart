import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/categories/data/models/category_dto.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';

class CategoriesRemoteDataSource {
  const CategoriesRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<Category>> getCategories({bool activeOnly = true}) async {
    final response = await _client.get(
      '/categories',
      queryParameters: {'active': activeOnly.toString(), 'limit': '100'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    return data
        .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Category> getCategory(int id) async {
    final response = await _client.get('/categories/$id');
    return CategoryDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Category> createCategory(Map<String, dynamic> data) async {
    final response = await _client.post('/categories', body: data);
    return CategoryDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Category> updateCategory(int id, Map<String, dynamic> data) async {
    final response = await _client.patch('/categories/$id', body: data);
    return CategoryDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteCategory(int id) async {
    await _client.delete('/categories/$id');
  }
}
