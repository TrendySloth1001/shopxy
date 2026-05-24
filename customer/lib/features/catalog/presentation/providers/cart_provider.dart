import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/cart_item.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';

/// Hard upper bound on a single line's quantity. Far above any plausible
/// retail order; mostly a guard against typos in the inline stepper and
/// API-time validation failures the UI hadn't filtered out.
const int kMaxLineQuantity = 999;

/// SharedPreferences key for the cart snapshot. Bumping the suffix
/// invalidates persisted carts that were written under an older shape.
const String _kCartStorageKey = 'customer.cart.v1';

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

  bool _restored = false;
  Timer? _saveDebounce;

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

  /// Outcome of an [add]/[setQuantity] call so the UI can show a
  /// targeted snackbar instead of silently dropping the input.
  AddToCartResult add(CatalogProduct product, {double quantity = 1}) {
    if (!product.inStock) {
      return AddToCartResult.outOfStock;
    }
    final existing = _lines[product.id];
    final current = existing?.quantity ?? 0;
    final desired = current + quantity;
    final capped = _capQuantity(desired, product);
    if (existing != null) {
      existing.quantity = capped;
    } else {
      _lines[product.id] = CartItem(product: product, quantity: capped);
    }
    _persist();
    notifyListeners();
    if (capped < desired) return AddToCartResult.capped;
    return AddToCartResult.ok;
  }

  /// Sets the quantity directly. Q <= 0 removes the line. If the line
  /// didn't exist, the call is a no-op — callers that want to *create*
  /// a new line should go through [add].
  AddToCartResult setQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      _lines.remove(productId);
      _persist();
      notifyListeners();
      return AddToCartResult.ok;
    }
    final line = _lines[productId];
    if (line == null) return AddToCartResult.missingLine;
    final capped = _capQuantity(quantity, line.product);
    line.quantity = capped;
    _persist();
    notifyListeners();
    return capped < quantity ? AddToCartResult.capped : AddToCartResult.ok;
  }

  void remove(int productId) {
    _lines.remove(productId);
    _persist();
    notifyListeners();
  }

  void setNote(String value) {
    _note = value;
    _persist();
  }

  void clear() {
    _lines.clear();
    _note = '';
    _error = null;
    _idempotencyKey = null;
    _persist();
    notifyListeners();
  }

  /// Group the cart by owning shop. Each entry is a list of lines that
  /// belong to one merchant. Lines without a known `shopId` are
  /// gathered under the `0` key — the checkout UI surfaces those as
  /// "Unknown merchant" so the user can remove them rather than fail
  /// the whole submit. After Phase 1 of the multi-tenant migration,
  /// every product carries its shopId so this bucket should be empty
  /// in practice.
  Map<int, List<CartItem>> get linesByShop {
    final byShop = <int, List<CartItem>>{};
    for (final line in _lines.values) {
      final shopId = line.product.shopId ?? 0;
      (byShop[shopId] ??= []).add(line);
    }
    return byShop;
  }

  /// Sum totals for a single shop group.
  double subtotalForShop(int shopId) {
    return _lines.values
        .where((l) => (l.product.shopId ?? 0) == shopId)
        .fold(0.0, (s, l) => s + l.lineTotal);
  }

  /// Sends the cart to the backend, grouped by shop. Fires one POST
  /// per shop with that shop's items, sharing one idempotency key (the
  /// server uses (userId, shopId, idempotencyKey) as the dedup key so
  /// a partial-success retry only re-creates the shops that failed).
  ///
  /// Returns the per-shop result map: `{ shopId: orderId | null }`.
  /// A null value means that shop's POST failed; `error` carries the
  /// last failure message. Returns null if the cart was empty.
  Future<Map<int, int?>?> placeOrders({int? addressId}) async {
    if (_lines.isEmpty) return null;
    _idempotencyKey ??= _newKey();
    _placing = true;
    _error = null;
    notifyListeners();
    final byShop = linesByShop;
    final results = <int, int?>{};
    var anyFailure = false;
    try {
      for (final entry in byShop.entries) {
        final shopId = entry.key;
        if (shopId == 0) {
          anyFailure = true;
          _error = 'Some items are missing a merchant attribution.';
          results[shopId] = null;
          continue;
        }
        try {
          final id = await _ordersDs.placeOrder(
            shopId: shopId,
            items: entry.value
                .map((l) => (productId: l.product.id, quantity: l.quantity))
                .toList(),
            note: _note.isEmpty ? null : _note,
            idempotencyKey: _idempotencyKey,
            addressId: addressId,
          );
          results[shopId] = id;
        } catch (e) {
          anyFailure = true;
          _error = e.toString().replaceFirst('Exception: ', '');
          results[shopId] = null;
        }
      }
      // Clear only the lines that successfully posted so the user can
      // retry the failed shops without duplicating the successful ones.
      for (final entry in results.entries) {
        if (entry.value == null) continue;
        _lines.removeWhere(
          (_, l) => (l.product.shopId ?? 0) == entry.key,
        );
      }
      if (!anyFailure) {
        _note = '';
        _idempotencyKey = null;
      }
      _persist();
      return results;
    } finally {
      _placing = false;
      notifyListeners();
    }
  }

  /// Single-shop convenience for legacy call sites. Returns the order
  /// id when the whole cart belongs to one shop, or null otherwise.
  Future<int?> placeOrder({int? addressId}) async {
    final results = await placeOrders(addressId: addressId);
    if (results == null) return null;
    final values = results.values.toList();
    if (values.length == 1) return values.first;
    return null;
  }

  /// Read the snapshot written by [_persist]. Wishlist/orders providers
  /// own their own restore loops; this one is fire-and-forget at boot.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartStorageKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final lines = (data['lines'] as List<dynamic>? ?? const []);
      for (final entry in lines) {
        final m = entry as Map<String, dynamic>;
        final product = CatalogProduct.fromJson(
          m['product'] as Map<String, dynamic>,
        );
        _lines[product.id] = CartItem(
          product: product,
          quantity: (m['quantity'] as num).toDouble(),
        );
      }
      _note = (data['note'] as String?) ?? '';
      _idempotencyKey = data['idempotencyKey'] as String?;
      if (_lines.isNotEmpty) notifyListeners();
    } catch (_) {
      // Corrupt snapshot — drop it and start fresh.
      _lines.clear();
      _note = '';
      _idempotencyKey = null;
    }
  }

  void _persist() {
    // Coalesce rapid mutations (stepper hold) into one write. 250ms is
    // imperceptible but cuts the I/O by 10x during a tap-storm.
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), _writeNow);
  }

  Future<void> _writeNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lines.isEmpty && _note.isEmpty) {
        await prefs.remove(_kCartStorageKey);
        return;
      }
      final payload = {
        'lines': _lines.values
            .map((l) => {
                  'quantity': l.quantity,
                  'product': _productJson(l.product),
                })
            .toList(),
        'note': _note,
        'idempotencyKey': _idempotencyKey,
      };
      await prefs.setString(_kCartStorageKey, jsonEncode(payload));
    } catch (_) {
      // Persistence failure is non-fatal — the cart still lives in
      // memory for the current session.
    }
  }

  Map<String, dynamic> _productJson(CatalogProduct p) => {
        'id': p.id,
        'name': p.name,
        'sku': p.sku,
        'unit': p.unit,
        'sellingPrice': p.sellingPrice,
        'mrp': p.mrp,
        'taxPercent': p.taxPercent,
        'stockQuantity': p.stockQuantity,
        if (p.imageUrl != null)
          'images': [
            {'url': p.imageUrl},
          ],
        if (p.description != null) 'description': p.description,
        if (p.hsnCode != null) 'hsnCode': p.hsnCode,
        if (p.categoryId != null) 'categoryId': p.categoryId,
        if (p.categoryName != null || p.categoryIconName != null)
          'category': {
            if (p.categoryName != null) 'name': p.categoryName,
            if (p.categoryIconName != null) 'iconName': p.categoryIconName,
          },
      };

  /// Cap a desired quantity by the product's stock and the hard line
  /// limit. Stock of 0 already short-circuits earlier in [add]; this
  /// path handles "user wants 100 of a 5-in-stock item".
  double _capQuantity(double desired, CatalogProduct product) {
    final stockCap = product.stockQuantity > 0
        ? product.stockQuantity
        : double.infinity;
    return math.min(
      math.min(desired, stockCap),
      kMaxLineQuantity.toDouble(),
    );
  }

  String _newKey() {
    final r = math.Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }
}

/// Outcome surfaced to callers so the UI can pick targeted copy
/// ("Out of stock", "Reached the cap of N", silent for the happy path).
enum AddToCartResult {
  ok,
  outOfStock,
  capped,
  /// `setQuantity` was called for a productId that wasn't in the cart.
  /// Callers must use [CartProvider.add] to create the line first.
  missingLine,
}
