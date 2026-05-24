import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/admin/data/models/admin_collection.dart';

class AdminCollectionsRemoteDataSource {
  AdminCollectionsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<AdminCollectionSummary>> list() async {
    final res = await _client.get(
      '/admin/collections',
      queryParameters: {'limit': '100'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load collections: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) =>
            AdminCollectionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminCollection> getOne(int id) async {
    final res = await _client.get('/admin/collections/$id');
    if (res.statusCode != 200) {
      throw Exception('Failed to load collection: ${res.body}');
    }
    return AdminCollection.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AdminCollectionSummary> create(Map<String, dynamic> body) async {
    final res = await _client.post('/admin/collections', body: body);
    if (res.statusCode != 201) {
      throw Exception('Create failed: ${res.body}');
    }
    return AdminCollectionSummary.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCollectionSummary> update(int id, Map<String, dynamic> body) async {
    final res = await _client.patch('/admin/collections/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.body}');
    }
    return AdminCollectionSummary.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<void> delete(int id) async {
    final res = await _client.delete('/admin/collections/$id');
    if (res.statusCode != 204) {
      throw Exception('Delete failed: ${res.body}');
    }
  }

  /// PUT replaces the entire item list — simpler and safer than diffing
  /// on the client. See backend collections.service.replaceItems for
  /// the transactional guarantees.
  Future<List<AdminCollectionItem>> replaceItems(
    int id,
    List<({int productId, int position})> items,
  ) async {
    final res = await _client.put(
      '/admin/collections/$id/items',
      body: {
        'items': items
            .map((i) => {'productId': i.productId, 'position': i.position})
            .toList(),
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Replace items failed: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => AdminCollectionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminCollectionProduct>> searchProducts(String q) async {
    final res = await _client.get(
      '/admin/collections/_search/products',
      queryParameters: {'q': q},
    );
    if (res.statusCode != 200) {
      throw Exception('Search failed: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) =>
            AdminCollectionProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
