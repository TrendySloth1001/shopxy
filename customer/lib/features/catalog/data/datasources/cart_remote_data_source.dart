import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';

class CartRemoteDataSource {
  const CartRemoteDataSource(this._client);
  final ApiClient _client;

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

  Future<CartLineDto?> setQuantity(String productId, double quantity) async {
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

  Future<void> remove(String productId) async {
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

  Future<List<CartLineDto>> merge(
    List<({String productId, double quantity})> items,
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
