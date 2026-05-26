import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';

/// Server-side cart. Calls /me/cart on the backend so the user's basket
/// follows them across devices. CartProvider keeps a SharedPreferences
/// cache for cold-boot rendering, but this data source is the source
/// of truth once the user is signed in.
class CartRemoteDataSource {
  const CartRemoteDataSource(this._client);
  final ApiClient _client;

  /// GET /me/cart — returns the full cart in render-ready shape.
  Future<List<CartLineDto>> list() async {
    final res = await _client.get('/me/cart');
    if (res.statusCode != 200) {
      throw Exception('Failed to load cart');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (json['data'] as List<dynamic>? ?? const []);
    return rows
        .map((e) => CartLineDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// PUT /me/cart/:productId — sets the absolute quantity. Returns the
  /// updated line, or null when quantity = 0 cleared the row. Throws
  /// when the product is out-of-stock or not purchasable.
  Future<CartLineDto?> setQuantity(int productId, double quantity) async {
    final res = await _client.put(
      '/me/cart/$productId',
      body: {'quantity': quantity},
    );
    if (res.statusCode == 204) return null;
    if (res.statusCode == 200) {
      return CartLineDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    if (res.statusCode == 409) {
      throw const CartException('Out of stock', code: 'OUT_OF_STOCK');
    }
    if (res.statusCode == 404) {
      throw const CartException(
        'Product is no longer available',
        code: 'PRODUCT_NOT_FOUND',
      );
    }
    throw Exception('Failed to update cart (${res.statusCode})');
  }

  Future<void> remove(int productId) async {
    final res = await _client.delete('/me/cart/$productId');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to remove from cart (${res.statusCode})');
    }
  }

  Future<void> clear() async {
    final res = await _client.delete('/me/cart');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Failed to clear cart (${res.statusCode})');
    }
  }

  /// POST /me/cart/merge — incoming items are summed into the server
  /// cart (capped by stock). Used once on first login to roll a guest
  /// cart into the user's persistent one.
  Future<List<CartLineDto>> merge(
    List<({int productId, double quantity})> items,
  ) async {
    final res = await _client.post(
      '/me/cart/merge',
      body: {
        'items': items
            .map((i) => {'productId': i.productId, 'quantity': i.quantity})
            .toList(),
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to merge cart (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (json['data'] as List<dynamic>? ?? const []);
    return rows
        .map((e) => CartLineDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class CartException implements Exception {
  const CartException(this.message, {required this.code});
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// Server response shape: `{ productId, quantity, product: {...} }`.
/// We don't model an `id` field because the customer only needs to
/// address rows by productId anyway.
class CartLineDto {
  const CartLineDto({
    required this.product,
    required this.quantity,
  });

  final CatalogProduct product;
  final double quantity;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory CartLineDto.fromJson(Map<String, dynamic> j) {
    return CartLineDto(
      product:
          CatalogProduct.fromJson(j['product'] as Map<String, dynamic>),
      quantity: _d(j['quantity']),
    );
  }
}
