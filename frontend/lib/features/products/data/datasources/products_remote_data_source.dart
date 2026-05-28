import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/products/data/models/product_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductsRemoteDataSource {
  const ProductsRemoteDataSource(this._client);
  final ApiClient _client;

  /// Throw with the backend's actual error text on any non-2xx. Without
  /// this guard, parsing an error body like `{error: "Validation failed"}`
  /// as a Product would crash with "null is not a subtype of int" on
  /// the strict `id: json['id'] as int` cast, hiding the real failure
  /// behind a useless Dart cast error.
  static void _expectOk(http.Response response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<({List<Product> products, int total})> getProducts({
    String? search,
    int? categoryId,
    bool? lowStock,
    bool? outOfStock,
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
    if (outOfStock == true) params['outOfStock'] = 'true';

    final response = await _client.get('/products', queryParameters: params);
    _expectOk(response, 'List products');
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
    _expectOk(response, 'Load product');
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
    _expectOk(response, 'Lookup product');
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final response = await _client.post('/products', body: data);
    _expectOk(response, 'Create product');
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final response = await _client.patch('/products/$id', body: data);
    _expectOk(response, 'Update product');
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteProduct(int id) async {
    final response = await _client.delete('/products/$id');
    _expectOk(response, 'Delete product');
  }

  /// Toggle the marketplace visibility flag. Backend exposes this as a
  /// distinct endpoint (`POST /products/:id/publish`) rather than a
  /// generic patch so the action can be audit-logged separately from
  /// editorial edits.
  Future<Product> setPublished(int id, bool isPublished) async {
    final response = await _client.post(
      '/products/$id/publish',
      body: {'isPublished': isPublished},
    );
    _expectOk(response, 'Publish product');
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Returns the created image record so callers can track its id
  /// (used by the edit form to mark the image as "already persisted"
  /// and avoid double-adding it during the next save).
  Future<ProductImage> addImage(int productId, String url) async {
    final response =
        await _client.post('/products/$productId/images', body: {'url': url});
    _expectOk(response, 'Add image');
    return ProductDto.imageFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteImage(int productId, int imageId) async {
    final response = await _client.delete('/products/$productId/images/$imageId');
    _expectOk(response, 'Delete image');
  }

  /// Uploads [file] to MinIO via the backend and returns the stored URL.
  Future<String> uploadImage(File file) async {
    final streamed = await _client.multipart(
      '/upload',
      makeFile: () => http.MultipartFile.fromPath('file', file.path),
    );
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 201) throw Exception('Upload failed: $body');
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['url'] as String;
  }
}
