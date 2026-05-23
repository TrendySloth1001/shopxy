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

  /// Paginated/searchable fetch used by the category picker. Returns
  /// `(rows, total)` so the caller can decide whether to load the next
  /// page. Stays out of [getCategories] so callers that want the
  /// small-shop default don't pay for the picker's extra plumbing.
  Future<({List<Category> categories, int total})> searchCategories({
    String? search,
    bool activeOnly = true,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get(
      '/categories',
      queryParameters: {
        'active': activeOnly.toString(),
        'page': '$page',
        'limit': '$limit',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    final categories = data
        .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = body['pagination'] as Map<String, dynamic>?;
    final total = (pagination?['total'] as int?) ?? categories.length;
    return (categories: categories, total: total);
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
