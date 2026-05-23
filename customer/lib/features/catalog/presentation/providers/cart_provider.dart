import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/cart_item.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';

class CartProvider extends ChangeNotifier {
  CartProvider(this._ordersDs);
  final OrdersRemoteDataSource _ordersDs;

  final Map<int, CartItem> _lines = {};
  String _note = '';
  bool _placing = false;
  String? _error;
  /// Sticky idempotency key for the current cart. Generated when the
  /// cart goes non-empty; persists across [placeOrder] retries so a
  /// failed submit can be retried without creating two orders. Cleared
  /// when the cart is emptied (successful submit or explicit clear).
  String? _idempotencyKey;

  List<CartItem> get lines => _lines.values.toList(growable: false);
  int get lineCount => _lines.length;
  int get totalItems =>
      _lines.values.fold(0, (sum, l) => sum + l.quantity.ceil());
  double get totalPrice =>
      _lines.values.fold(0.0, (sum, l) => sum + l.lineTotal);
  String get note => _note;
  bool get isPlacing => _placing;
  String? get error => _error;
  bool get isEmpty => _lines.isEmpty;

  CartItem? lineFor(int productId) => _lines[productId];

  void add(CatalogProduct product, {double quantity = 1}) {
    final existing = _lines[product.id];
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _lines[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
  }

  void setQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      _lines.remove(productId);
    } else {
      final line = _lines[productId];
      if (line == null) return;
      line.quantity = quantity;
    }
    notifyListeners();
  }

  void remove(int productId) {
    _lines.remove(productId);
    notifyListeners();
  }

  void setNote(String value) {
    _note = value;
  }

  void clear() {
    _lines.clear();
    _note = '';
    _error = null;
    _idempotencyKey = null;
    notifyListeners();
  }

  /// Sends the cart to the backend. Returns the new order's id on
  /// success, or null on failure (with [error] populated). Carries a
  /// per-cart idempotency key so retrying a failed submit doesn't
  /// create a duplicate order.
  Future<int?> placeOrder() async {
    if (_lines.isEmpty) return null;
    _idempotencyKey ??= _newKey();
    _placing = true;
    _error = null;
    notifyListeners();
    try {
      final id = await _ordersDs.placeOrder(
        items: _lines.values
            .map((l) => (productId: l.product.id, quantity: l.quantity))
            .toList(),
        note: _note.isEmpty ? null : _note,
        idempotencyKey: _idempotencyKey,
      );
      _lines.clear();
      _note = '';
      _idempotencyKey = null;
      return id;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _placing = false;
      notifyListeners();
    }
  }

  String _newKey() {
    final r = math.Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }
}
