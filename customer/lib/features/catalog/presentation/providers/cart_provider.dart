import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/cart_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/cart_item.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

class PlaceOrderResult {
  const PlaceOrderResult.success({
    required this.orderId,
    required this.shopOrderCount,
  })  : error = null;
  const PlaceOrderResult.failure(this.error)
      : orderId = null,
        shopOrderCount = 0;

  final String? orderId;
  final int shopOrderCount;
  final String? error;

  bool get isSuccess => orderId != null;
}

const int kMaxLineQuantity = 999;

const String _kCartStorageKey = 'customer.cart.v3';

class CartProvider extends ChangeNotifier {
  CartProvider(this._ordersDs, this._cartDs);
  final OrdersRemoteDataSource _ordersDs;
  final CartRemoteDataSource _cartDs;

  final Map<String, CartItem> _lines = {};
  String _note = '';
  bool _placing = false;
  String? _error;

  String? _idempotencyKey;

  bool _restored = false;
  Timer? _saveDebounce;

  bool _serverSynced = false;
  Future<void>? _syncInFlight;

  bool _hasGuestChanges = false;

  final Map<String, CartLineSyncStatus> _lineSync = {};

  final StreamController<String> _syncErrors =
      StreamController<String>.broadcast();
  Stream<String> get syncErrors => _syncErrors.stream;

  CartLineSyncStatus? lineSyncStatus(String productId) => _lineSync[productId];

  List<CartItem> get lines => _lines.values.toList(growable: false);
  int get lineCount => _lines.length;
  int get totalItems =>
      _lines.values.fold(0, (sum, l) => sum + l.quantity.ceil());
  double get totalPrice =>
      _lines.values.fold(0.0, (sum, l) => sum + l.lineTotal);
  double get itemsTotal => totalPrice;
  double get savings => _lines.values.fold(0.0, (sum, l) {
        final mrp = l.product.mrp;
        final selling = l.product.sellingPrice;
        return mrp > selling ? sum + (mrp - selling) * l.quantity : sum;
      });

  double get mrpTotal => totalPrice + savings;
  List<String> get shopIds {
    final s = <String>{};
    for (final l in _lines.values) {
      final id = l.product.shopId;
      if (id != null) s.add(id);
    }
    return s.toList(growable: false);
  }
  String get note => _note;
  bool get isPlacing => _placing;
  String? get error => _error;
  bool get isEmpty => _lines.isEmpty;

  CartItem? lineFor(String productId) => _lines[productId];

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
    if (!_serverSynced) _hasGuestChanges = true;
    _persist();
    _syncLineToServer(product.id, capped);
    notifyListeners();
    if (capped < desired) return AddToCartResult.capped;
    return AddToCartResult.ok;
  }

  AddToCartResult setQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      _lines.remove(productId);
      if (!_serverSynced) _hasGuestChanges = true;
      _persist();
      _syncLineToServer(productId, 0);
      notifyListeners();
      return AddToCartResult.ok;
    }
    final line = _lines[productId];
    if (line == null) return AddToCartResult.missingLine;
    final capped = _capQuantity(quantity, line.product);
    line.quantity = capped;
    if (!_serverSynced) _hasGuestChanges = true;
    _persist();
    _syncLineToServer(productId, capped);
    notifyListeners();
    return capped < quantity ? AddToCartResult.capped : AddToCartResult.ok;
  }

  void remove(String productId) {
    _lines.remove(productId);
    if (!_serverSynced) _hasGuestChanges = true;
    _persist();
    _syncLineToServer(productId, 0);
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
    if (_serverSynced) {
      // ignore: unawaited_futures
      _cartDs.clear().catchError((_) {});
    }
    notifyListeners();
  }

  Map<String, List<CartItem>> get linesByShop {
    final byShop = <String, List<CartItem>>{};
    for (final line in _lines.values) {
      final shopId = line.product.shopId ?? '0';
      (byShop[shopId] ??= []).add(line);
    }
    return byShop;
  }

  double subtotalForShop(String shopId) {
    return _lines.values
        .where((l) => (l.product.shopId ?? '0') == shopId)
        .fold(0.0, (s, l) => s + l.lineTotal);
  }

  Future<PlaceOrderResult> placeOrder({
    String? addressId,
    String? couponCode,
    bool claimGst = false,
  }) async {
    if (_lines.isEmpty) {
      return const PlaceOrderResult.failure('EMPTY_CART');
    }
    _idempotencyKey ??= _newKey();
    _placing = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _ordersDs.placeOrder(
        items: _lines.values
            .map((l) => (
                  productId: l.product.id,
                  quantity: l.quantity,
                  expectedUnitPrice: null,
                ))
            .toList(),
        note: _note.isEmpty ? null : _note,
        idempotencyKey: _idempotencyKey,
        addressId: addressId,
        couponCode: couponCode,
        claimGst: claimGst,
      );
      final clearedIds = _lines.keys.toList();
      _lines.clear();
      for (final id in clearedIds) {
        _syncLineToServer(id, 0);
      }
      _note = '';
      _idempotencyKey = null;
      _persist();
      return PlaceOrderResult.success(
        orderId: response.orderId,
        shopOrderCount: response.shopOrders.length,
      );
    } on PriceDriftException catch (e) {
      for (final drift in e.drifts) {
        final line = _lines[drift.productId];
        if (line == null) continue;
        _lines[drift.productId] = CartItem(
          product: line.product.copyWithPrice(drift.actualUnitPrice),
          quantity: line.quantity,
        );
      }
      _persist();
      _error =
          'Prices have changed since you viewed the cart. Please review and try again.';
      return const PlaceOrderResult.failure('PRICE_DRIFT');
    } catch (e) {
      final msg = friendlyError(e);
      _error = msg;
      return PlaceOrderResult.failure(msg);
    } finally {
      _placing = false;
      notifyListeners();
    }
  }

  Future<GatewayCheckout> payForOrder(String orderId) =>
      _ordersDs.payForOrder(orderId);

  Future<String> syncOrderPayment(String orderId) =>
      _ordersDs.syncOrderPayment(orderId);

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
      _hasGuestChanges = (data['hasGuestChanges'] as bool?) ?? false;
      if (_lines.isNotEmpty) notifyListeners();
    } catch (_) {
      _lines.clear();
      _note = '';
      _idempotencyKey = null;
      _hasGuestChanges = false;
    }
  }

  Future<void> syncFromServer({bool mergeLocal = true}) {
    return _syncInFlight ??= _runSync(mergeLocal: mergeLocal)
        .whenComplete(() => _syncInFlight = null);
  }

  Future<void> _runSync({required bool mergeLocal}) async {
    try {
      List<CartLineDto> serverLines;
      final shouldMerge =
          mergeLocal && _hasGuestChanges && _lines.isNotEmpty;
      if (shouldMerge) {
        final payload = _lines.values
            .map((l) => (productId: l.product.id, quantity: l.quantity))
            .toList();
        serverLines = await _cartDs.merge(payload);
      } else {
        serverLines = await _cartDs.list();
      }
      _lines.clear();
      for (final l in serverLines) {
        _lines[l.product.id] = CartItem(product: l.product, quantity: l.quantity);
      }
      _serverSynced = true;
      _hasGuestChanges = false;
      _persist();
      notifyListeners();
    } catch (_) {
    }
  }

  void onLoggedOut() {
    _serverSynced = false;
    _syncInFlight = null;
  }

  void _syncLineToServer(String productId, double quantity) {
    if (!_serverSynced) return;
    final priorLine = _lines[productId];
    final priorQty = priorLine?.quantity;
    _lineSync[productId] = CartLineSyncStatus.syncing;

    Future<void> call;
    if (quantity <= 0) {
      call = _cartDs.remove(productId);
    } else {
      call = _cartDs.setQuantity(productId, quantity).then((_) {});
    }
    // ignore: unawaited_futures
    call.then((_) {
      _lineSync.remove(productId);
      notifyListeners();
    }).catchError((Object err) {
      if (priorQty == null || priorLine == null) {
        _lines.remove(productId);
      } else {
        _lines[productId] = CartItem(
          product: priorLine.product,
          quantity: priorQty,
        );
      }
      _lineSync[productId] = CartLineSyncStatus.dirty;
      _persist();
      notifyListeners();
      if (!_syncErrors.isClosed) {
        _syncErrors.add(
          "Couldn't update your cart. Check your connection and try again.",
        );
      }
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _syncErrors.close();
    super.dispose();
  }

  void _persist() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(AppDurations.medium, _writeNow);
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
        'hasGuestChanges': _hasGuestChanges,
      };
      await prefs.setString(_kCartStorageKey, jsonEncode(payload));
    } catch (_) {
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
        if (p.shopId != null) 'shopId': p.shopId,
        if (p.shopName != null || p.shopSlug != null)
          'shop': {
            if (p.shopId != null) 'id': p.shopId,
            if (p.shopName != null) 'name': p.shopName,
            if (p.shopSlug != null) 'slug': p.shopSlug,
          },
      };

  double _capQuantity(double desired, CatalogProduct product) {
    if (product.stockQuantity <= 0) return 0;
    return math.min(
      math.min(desired, product.stockQuantity),
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

enum CartLineSyncStatus { syncing, dirty }

enum AddToCartResult {
  ok,
  outOfStock,
  capped,
  missingLine,
}
