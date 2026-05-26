import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/cart_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/cart_item.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';

/// Outcome of [CartProvider.placeOrder]. On success [orderId] is the
/// parent CustomerOrder id and [shopOrderCount] is how many vendor
/// slices the server fanned out (the customer's cart spanned that
/// many shops). On failure [error] carries the raw backend code so
/// the checkout UI can render a meaningful message.
class PlaceOrderResult {
  const PlaceOrderResult.success({
    required this.orderId,
    required this.shopOrderCount,
  })  : error = null;
  const PlaceOrderResult.failure(this.error)
      : orderId = null,
        shopOrderCount = 0;

  final int? orderId;
  final int shopOrderCount;
  final String? error;

  bool get isSuccess => orderId != null;
}

/// Hard upper bound on a single line's quantity. Far above any plausible
/// retail order; mostly a guard against typos in the inline stepper and
/// API-time validation failures the UI hadn't filtered out.
const int kMaxLineQuantity = 999;

/// SharedPreferences key for the cart snapshot. Bumping the suffix
/// invalidates persisted carts that were written under an older shape.
/// v2 added shop attribution (id/name/slug) to each line so restored
/// carts keep the "Sold by" chip and place orders correctly.
/// v3 added the server-sync layer; the cache now mirrors what the
/// server returned (or, before login, the guest cart awaiting merge).
const String _kCartStorageKey = 'customer.cart.v3';

/// Authoritative cart. Behaviour:
///   • Signed out → cart lives in SharedPreferences (the "guest cart").
///   • On login → guest cart is POSTed to /me/cart/merge, then we
///     pull the merged cart down. From that point every mutation is
///     mirrored to the server via debounced PUT/DELETE.
///   • Signed-in cold start → we hydrate from SharedPreferences first
///     (so first paint isn't blank), then re-fetch from /me/cart and
///     overwrite the local state.
///
/// The server is the source of truth once authenticated. Local
/// persistence remains for cold-boot rendering and for guest carts
/// pre-login.
class CartProvider extends ChangeNotifier {
  CartProvider(this._ordersDs, this._cartDs);
  final OrdersRemoteDataSource _ordersDs;
  final CartRemoteDataSource _cartDs;

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

  /// True once the user is authenticated and either the merge or the
  /// pull has completed. Used to decide whether mutations should be
  /// mirrored to the server.
  bool _serverSynced = false;
  Future<void>? _syncInFlight;

  /// Per-line sync state. A line is `syncing` while a server mutation
  /// is in flight, and `dirty` if the most recent server mutation
  /// failed and the local change has been rolled back. The UI can
  /// peek at this to render a spinner or an error chip.
  final Map<int, CartLineSyncStatus> _lineSync = {};

  /// Snackbar bus for persistent sync failures. The cart page (or any
  /// screen visible at the time) subscribes and surfaces a snackbar so
  /// the user knows their last quantity change didn't make it to the
  /// server.
  final StreamController<String> _syncErrors =
      StreamController<String>.broadcast();
  Stream<String> get syncErrors => _syncErrors.stream;

  CartLineSyncStatus? lineSyncStatus(int productId) => _lineSync[productId];

  List<CartItem> get lines => _lines.values.toList(growable: false);
  int get lineCount => _lines.length;
  int get totalItems =>
      _lines.values.fold(0, (sum, l) => sum + l.quantity.ceil());
  double get totalPrice =>
      _lines.values.fold(0.0, (sum, l) => sum + l.lineTotal);
  /// Subtotal of all line items at their current selling price — same
  /// number the checkout's "Items total" row renders. Exposed under a
  /// market-standard name so checkout helpers (coupon validate, wallet
  /// preview) don't have to recompute the fold.
  double get itemsTotal => totalPrice;
  /// Distinct shop ids the cart spans. Used by coupon validation to
  /// enforce shop-scoped redemption rules.
  List<int> get shopIds {
    final s = <int>{};
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
    _syncLineToServer(product.id, capped);
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
      _syncLineToServer(productId, 0);
      notifyListeners();
      return AddToCartResult.ok;
    }
    final line = _lines[productId];
    if (line == null) return AddToCartResult.missingLine;
    final capped = _capQuantity(quantity, line.product);
    line.quantity = capped;
    _persist();
    _syncLineToServer(productId, capped);
    notifyListeners();
    return capped < quantity ? AddToCartResult.capped : AddToCartResult.ok;
  }

  void remove(int productId) {
    _lines.remove(productId);
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
      // Fire-and-forget — the local clear is the authoritative UX
      // change; a network failure to mirror it is acceptable because
      // the next list() refresh will heal.
      // ignore: unawaited_futures
      _cartDs.clear().catchError((_) {});
    }
    notifyListeners();
  }

  /// Group the cart by owning shop. Each entry is a list of lines that
  /// belong to one merchant. Lines without a known `shopId` are
  /// gathered under the `0` key — the checkout UI surfaces those as
  /// "Unknown merchant" so the user can remove them rather than fail
  /// the whole submit.
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

  /// Sends the whole cart to the backend in one POST. The server groups
  /// items by shop and creates one parent CustomerOrder plus one
  /// PurchaseRequest per shop. On success the cart is cleared; on
  /// failure the cart is preserved so the user can retry.
  Future<PlaceOrderResult> placeOrder({
    int? addressId,
    String? couponCode,
    bool useWallet = false,
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
            .map((l) => (productId: l.product.id, quantity: l.quantity))
            .toList(),
        note: _note.isEmpty ? null : _note,
        idempotencyKey: _idempotencyKey,
        addressId: addressId,
        couponCode: couponCode,
        useWallet: useWallet,
      );
      // Whole cart placed — clear local state and persist the empty
      // snapshot so a cold-boot doesn't restore the just-submitted
      // items.
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
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _error = msg;
      return PlaceOrderResult.failure(msg);
    } finally {
      _placing = false;
      notifyListeners();
    }
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

  /// Called once on login (and on app start if already authenticated)
  /// so the local cart syncs with the server. Behaviour:
  ///   • If we have local lines (guest cart), POST /me/cart/merge to
  ///     sum them into the user's server cart.
  ///   • Then GET /me/cart and overwrite the local state.
  /// Dedup'd so concurrent calls (e.g. login + app-init race) only
  /// run one round-trip.
  Future<void> syncFromServer({bool mergeLocal = true}) {
    return _syncInFlight ??= _runSync(mergeLocal: mergeLocal)
        .whenComplete(() => _syncInFlight = null);
  }

  Future<void> _runSync({required bool mergeLocal}) async {
    try {
      List<CartLineDto> serverLines;
      if (mergeLocal && _lines.isNotEmpty) {
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
      _persist();
      notifyListeners();
    } catch (_) {
      // Best-effort. Local cart stays as-is so the user still sees
      // their items; we'll retry on the next mutation.
    }
  }

  /// Called by AuthProvider on logout so the next sign-in starts
  /// clean. We DO NOT clear the local cart here — the user may want
  /// to keep their items as a guest after logging out.
  void onLoggedOut() {
    _serverSynced = false;
    _syncInFlight = null;
  }

  /// Mirror a single line mutation to the server. No-op when the user
  /// isn't signed in yet (the local cart is still authoritative until
  /// [syncFromServer] runs). On failure we roll back the local change
  /// to whatever was there before, flip the line's status to `dirty`,
  /// notify listeners so the UI repaints, and emit a snackbar event
  /// so the user is told the change didn't stick.
  void _syncLineToServer(int productId, double quantity) {
    if (!_serverSynced) return;
    // Snapshot the previous line so we can roll back on failure.
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
      // Roll back the optimistic local change.
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
        // Persist the owning shop so a restored cart still knows which
        // merchant each line belongs to. Without this, the cart UI
        // can't render "Sold by …" chips and placeOrders falls back to
        // the shopId-less "0" bucket which the server rejects.
        if (p.shopId != null) 'shopId': p.shopId,
        if (p.shopName != null || p.shopSlug != null)
          'shop': {
            if (p.shopId != null) 'id': p.shopId,
            if (p.shopName != null) 'name': p.shopName,
            if (p.shopSlug != null) 'slug': p.shopSlug,
          },
      };

  /// Cap a desired quantity by the product's stock and the hard line
  /// limit. When the product is out of stock we deliberately return 0
  /// (not infinity) — that lets [setQuantity] drop the line cleanly
  /// instead of letting the user crank the stepper to kMaxLineQuantity
  /// against a depleted SKU only to be rejected at checkout.
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

/// Per-line server-sync state. `syncing` while a PUT/DELETE is in
/// flight; `dirty` after the most recent attempt failed and the
/// optimistic local change was rolled back.
enum CartLineSyncStatus { syncing, dirty }

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
