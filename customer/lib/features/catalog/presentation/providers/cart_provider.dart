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
    notifyListeners();
  }

  /// Sends the cart to the backend. Returns the new order's id on
  /// success, or null on failure (with [error] populated).
  Future<int?> placeOrder() async {
    if (_lines.isEmpty) return null;
    _placing = true;
    _error = null;
    notifyListeners();
    try {
      final id = await _ordersDs.placeOrder(
        items: _lines.values
            .map((l) => (productId: l.product.id, quantity: l.quantity))
            .toList(),
        note: _note.isEmpty ? null : _note,
      );
      _lines.clear();
      _note = '';
      return id;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _placing = false;
      notifyListeners();
    }
  }
}
