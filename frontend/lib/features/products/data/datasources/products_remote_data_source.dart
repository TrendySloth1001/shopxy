import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/products/data/models/hsn_dto.dart';
import 'package:shopxy/features/products/data/models/product_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductsRemoteDataSource {
  const ProductsRemoteDataSource(this._client);
  final ApiClient _client;

  static void _expectOk(http.Response response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<({List<Product> products, int total})> getProducts({
    String? search,
    String? categoryId,
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

  Future<({List<Product> products, int total, bool truncated})>
  getCatalogue() async {
    final response = await _client.get('/products/catalogue');
    _expectOk(response, 'Load product catalogue');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List;

    return (
      products: data
          .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: body['total'] as int? ?? data.length,
      truncated: body['truncated'] as bool? ?? false,
    );
  }

  Future<Product> getProduct(String id) async {
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

  Future<Product> updateProduct(String id, Map<String, dynamic> data) async {
    final response = await _client.patch('/products/$id', body: data);
    _expectOk(response, 'Update product');
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteProduct(String id) async {
    final response = await _client.delete('/products/$id');
    _expectOk(response, 'Delete product');
  }

  Future<Product> setPublished(String id, bool isPublished) async {
    final response = await _client.post(
      '/products/$id/publish',
      body: {'isPublished': isPublished},
    );
    _expectOk(response, 'Publish product');
    return ProductDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ProductImage> addImage(String productId, String url) async {
    final response =
        await _client.post('/products/$productId/images', body: {'url': url});
    _expectOk(response, 'Add image');
    return ProductDto.imageFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteImage(String productId, String imageId) async {
    final response = await _client.delete('/products/$productId/images/$imageId');
    _expectOk(response, 'Delete image');
  }

  Future<List<HsnMatch>> searchHsn(String query) async {
    try {
      final response = await _client.get('/hsn', queryParameters: {'q': query});
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['results'] as List? ?? const [])
          .map((e) => HsnMatch.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<HsnSuggestion>> suggestHsn(String name) async {
    if (name.trim().isEmpty) return const [];
    try {
      final response =
          await _client.get('/hsn/suggest', queryParameters: {'name': name});
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['suggestions'] as List? ?? const [])
          .map((e) => HsnSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<HsnResolution?> resolveHsn(String code, {double? price}) async {
    try {
      final response = await _client.get('/hsn/resolve', queryParameters: {
        'code': code,
        if (price != null && price.isFinite) 'price': price.toString(),
      });
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return HsnResolution.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveHsnShortcut({required String label, required String code}) async {
    try {
      final response = await _client.post(
        '/hsn/shortcuts',
        body: {'label': label, 'code': code},
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Never _fail(http.Response response, String action) {
    String message = '$action failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) message = body['error'] as String;
    } catch (_) {
    }
    throw Exception(message);
  }

  Future<List<HsnShortcut>> listHsnShortcuts() async {
    final response = await _client.get('/hsn/shortcuts');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail(response, 'Load saved codes');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['shortcuts'] as List? ?? const [])
        .map((e) => HsnShortcut.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteHsnShortcut(String id) async {
    final response = await _client.delete('/hsn/shortcuts/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail(response, 'Remove saved code');
    }
  }

  Future<List<HsnOverride>> listHsnOverrides() async {
    final response = await _client.get('/hsn/overrides');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail(response, 'Load rate overrides');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['overrides'] as List? ?? const [])
        .map((e) => HsnOverride.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createHsnOverride({
    required String code,
    required double gstRate,
    required String reason,
  }) async {
    final response = await _client.post('/hsn/overrides', body: {
      'code': code,
      'gstRate': gstRate,
      'reason': reason,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail(response, 'Save rate override');
    }
  }

  Future<void> deleteHsnOverride(String id) async {
    final response = await _client.delete('/hsn/overrides/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail(response, 'Remove rate override');
    }
  }

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
