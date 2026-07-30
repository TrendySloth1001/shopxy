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

  /// The whole active catalogue in one light response, for searching locally.
  ///
  /// `truncated` means the shop has more products than the server will send at
  /// once. It is not a hint — a caller that searches a truncated list will tell
  /// a merchant their own SKU doesn't exist, so the only correct response is to
  /// abandon local search and ask the server.
  ///
  /// Goes through `ApiClient.get`, so it inherits the cache-first read: a cold
  /// start paints from the last catalogue on disk and revalidates behind it,
  /// and the whole thing keeps working offline.
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

  /// Toggle the marketplace visibility flag. Backend exposes this as a
  /// distinct endpoint (`POST /products/:id/publish`) rather than a
  /// generic patch so the action can be audit-logged separately from
  /// editorial edits.
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

  /// Returns the created image record so callers can track its id
  /// (used by the edit form to mark the image as "already persisted"
  /// and avoid double-adding it during the next save).
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

  /// ── HSN/SAC rate master ────────────────────────────────────────────────
  /// Reference data behind the product editor's "type a code, get the GST
  /// rate" auto-fill. Read-only — the master is seeded server-side from a
  /// checked-in manifest, so there is nothing to write back.

  /// Type-ahead over codes, the translated alias vocabulary and the merchant's
  /// own saved shortcuts. Returns an empty list rather than throwing: a failed
  /// lookup must not block the merchant from typing a code by hand.
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

  /// Classification from a product name, so the merchant confirms a code
  /// instead of hunting for one. Quiet on failure for the same reason as
  /// [searchHsn] — a suggester that throws is worse than one that says nothing.
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

  /// The rate lookup: one code in, the rate it bills at out.
  ///
  /// [price] matters — apparel is 5% up to ₹2,500 a piece and 18% above, so the
  /// same code answers differently depending on what's being charged.
  ///
  /// Null means the master carries no rate for the code (a 404). Callers MUST
  /// leave the tax field as it was rather than defaulting to 0% — a silent 0
  /// is an under-charged invoice, the exact failure this feature prevents.
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

  /// Save "when I say X, I mean this code". Stores no rate by design — the rate
  /// is always read live, so a saved shortcut can never go stale against a
  /// Council revision.
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

  /// ── Managing the merchant's own codes ──────────────────────────────────
  ///
  /// The calls above are quiet on failure because they run on the typing path,
  /// where an exception would interrupt an edit for no gain. These are the
  /// opposite: they back the "My HSN codes" screen, where swallowing an error
  /// would make a refused delete look like it worked. A 403 in particular is
  /// meaningful — overrides need `shop:manage`, which a cashier doesn't hold.
  static Never _fail(http.Response response, String action) {
    String message = '$action failed (${response.statusCode})';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) message = body['error'] as String;
    } catch (_) {
      // Non-JSON body — keep the status-code message.
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

  /// Removing a shortcut only forgets a bookmark — nothing already priced
  /// changes, because a shortcut never carried a rate.
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

  /// Soft on the backend: the override stops applying to new documents but
  /// stays on the record, because it was the shop's stated position when
  /// earlier invoices were raised.
  Future<void> deleteHsnOverride(String id) async {
    final response = await _client.delete('/hsn/overrides/$id');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail(response, 'Remove rate override');
    }
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
