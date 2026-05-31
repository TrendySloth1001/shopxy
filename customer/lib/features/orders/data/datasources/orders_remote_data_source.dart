import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';

/// Differentiated cancel failure thrown by the data source so the UI can
/// render targeted copy instead of "Could not cancel".
class CancelOrderException implements Exception {
  CancelOrderException(this.code, this.message);
  /// One of: NOT_FOUND, NOT_OWNED, NOT_PENDING, UNKNOWN.
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// One line whose live price disagreed with what the customer was shown.
class PriceDrift {
  const PriceDrift({
    required this.productId,
    required this.expectedUnitPrice,
    required this.actualUnitPrice,
  });
  final int productId;
  final double expectedUnitPrice;
  final double actualUnitPrice;
}

/// Server rejected the place-order because one or more line prices
/// moved between cart + submit (e.g. a flash sale ended). Carries the
/// corrected prices so the UI can re-show the cart with a clear callout.
class PriceDriftException implements Exception {
  PriceDriftException(this.drifts);
  final List<PriceDrift> drifts;

  @override
  String toString() => 'Prices have changed since you viewed the cart.';
}

/// Result of placing an order — returns the parent `CustomerOrder` id
/// and the per-vendor child slices the server created. The customer UI
/// uses the parent id to navigate to the new order detail; the child
/// ids are useful for surfacing "3 vendors will fulfil this" copy
/// without an extra round trip.
class PlaceOrderResponse {
  const PlaceOrderResponse({required this.orderId, required this.shopOrders});
  final int orderId;
  /// Per-vendor child ids + shopIds — matches the server's
  /// `shopOrders: [{ id, shopId }]` response.
  final List<({int id, int shopId})> shopOrders;
}

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._client);
  final ApiClient _client;

  /// Single POST that hands the whole cart to the server. Server groups
  /// by shop and creates one parent CustomerOrder + N PurchaseRequest
  /// children in one transaction. Idempotent per [idempotencyKey].
  Future<PlaceOrderResponse> placeOrder({
    required List<({int productId, double quantity, double? expectedUnitPrice})>
        items,
    String? note,
    String? idempotencyKey,
    int? addressId,
    String? couponCode,
    bool useWallet = false,
  }) async {
    final key = idempotencyKey ?? _newIdempotencyKey();
    final res = await _client.post(
      '/me/orders',
      extraHeaders: {'X-Idempotency-Key': key},
      body: {
        'items': items
            .map((i) => {
                  'productId': i.productId,
                  'quantity': i.quantity,
                  if (i.expectedUnitPrice != null)
                    'expectedUnitPrice': i.expectedUnitPrice,
                })
            .toList(),
        if (note != null && note.isNotEmpty) 'note': note,
        'addressId': ?addressId,
        if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
        if (useWallet) 'useWallet': true,
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      // PRICE_DRIFT specifically carries a per-line breakdown in
      // `details`; surface it via a typed exception so the cart can
      // re-quote + re-show with the corrected prices.
      if (res.statusCode == 409 && err['error'] == 'PRICE_DRIFT') {
        final details = ((err['details'] as List?) ?? const [])
            .map((e) {
              final m = e as Map<String, dynamic>;
              return PriceDrift(
                productId: (m['productId'] as num).toInt(),
                expectedUnitPrice: (m['expectedUnitPrice'] as num).toDouble(),
                actualUnitPrice: (m['actualUnitPrice'] as num).toDouble(),
              );
            })
            .toList(growable: false);
        throw PriceDriftException(details);
      }
      throw Exception(err['error'] ?? 'Order failed');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final shopOrders = ((json['shopOrders'] as List?) ?? const [])
        .map((e) {
          final m = e as Map<String, dynamic>;
          return (id: m['id'] as int, shopId: m['shopId'] as int);
        })
        .toList(growable: false);
    return PlaceOrderResponse(
      orderId: json['id'] as int,
      shopOrders: shopOrders,
    );
  }

  Future<List<CustomerOrder>> list({int page = 1, int limit = 30}) async {
    final res = await _client.get('/me/orders', queryParameters: {
      'page': '$page',
      'limit': '$limit',
    });
    if (res.statusCode != 200) {
      throw Exception('Failed to load orders');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => CustomerOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerOrderDetail> detail(int id) async {
    final res = await _client.get('/me/orders/$id');
    if (res.statusCode != 200) throw Exception('Order not found');
    return CustomerOrderDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Cancel one shop's slice of a customer order. The parent and the
  /// other shops in the same checkout are unaffected.
  Future<void> cancelShopOrder({
    required int parentId,
    required int childId,
  }) async {
    final res =
        await _client.post('/me/orders/$parentId/shops/$childId/cancel');
    if (res.statusCode == 204) return;
    String code = 'UNKNOWN';
    String message = 'Could not cancel order';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      code = (body['code'] as String?) ?? code;
      message = (body['error'] as String?) ?? message;
    } catch (_) {/* keep defaults */}
    throw CancelOrderException(code, message);
  }

  /// Reorder a previous order — server returns the cart-ready line
  /// items (each with the full product payload) plus a `skipped` list
  /// (UNAVAILABLE / OWN_SHOP) for the client toast.
  Future<({List<({CatalogProduct product, double quantity})> items,
          List<({int productId, String productName, String reason})> skipped})>
      reorder(int parentId) async {
    final res = await _client.post('/me/orders/$parentId/reorder');
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Could not reorder');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = ((json['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) => (
              product: CatalogProduct.fromJson(
                m['product'] as Map<String, dynamic>,
              ),
              quantity: (m['quantity'] as num).toDouble(),
            ))
        .toList();
    final skipped = ((json['skipped'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) => (
              productId: (m['productId'] as num).toInt(),
              productName: (m['productName'] as String?) ?? '',
              reason: (m['reason'] as String?) ?? 'UNAVAILABLE',
            ))
        .toList();
    return (items: items, skipped: skipped);
  }

  /// Download an invoice PDF as raw bytes. Caller decides what to do
  /// with them (save to documents, hand to the platform share sheet,
  /// open with the OS PDF viewer). Goes direct via `http.get` instead
  /// of [ApiClient.get] because we want bytes back, not a parsed body.
  Future<Uint8List> downloadInvoicePdf({
    required int parentId,
    required int childId,
    required String accessToken,
  }) async {
    final base = AppConfig.apiBaseUrl;
    final path = 'me/orders/$parentId/shops/$childId/invoice.pdf';
    final res = await http.get(
      Uri.parse('$base$path'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      throw Exception('Could not download invoice (${res.statusCode})');
    }
    return res.bodyBytes;
  }

  /// Lightweight UUID-v4-shaped string, sufficient for idempotency.
  /// Doesn't pull in a uuid package — 122 random bits give us collision
  /// resistance well beyond what the customer needs.
  static String _newIdempotencyKey() {
    final r = Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    final s = '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
    return s;
  }

  /// Start an online gateway payment for an order's payable remainder.
  /// Returns the checkout session the app opens the Razorpay sheet with.
  Future<GatewayCheckout> payForOrder(int orderId) async {
    final res = await _client.post('/me/orders/$orderId/pay');
    if (res.statusCode != 201) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Could not start payment');
    }
    return GatewayCheckout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Client-confirm after the Razorpay sheet reports success. The server
  /// re-checks the live provider order and settles if paid (a backstop for the
  /// webhook, which can't reach a localhost dev server and may lag in prod).
  /// Returns the order's resulting paymentStatus (e.g. 'PAID'). Best-effort:
  /// the webhook is still authoritative, so a failure here is non-fatal.
  Future<String> syncOrderPayment(int orderId) async {
    final res = await _client.post('/me/orders/$orderId/payment/sync');
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Could not sync payment');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['paymentStatus'] as String?) ?? 'PENDING';
  }
}

/// The checkout session returned by `POST /me/orders/:id/pay` — mirrors the
/// backend's gateway InitiateResult. `clientParams` is the provider-specific
/// bag (Razorpay: key / order_id / amount / currency) fed to the sheet.
class GatewayCheckout {
  const GatewayCheckout({
    required this.intentId,
    required this.provider,
    required this.providerOrderRef,
    required this.amount,
    required this.currency,
    required this.clientParams,
  });

  final int intentId;
  final String provider;
  final String providerOrderRef;
  final double amount;
  final String currency;
  final Map<String, dynamic> clientParams;

  factory GatewayCheckout.fromJson(Map<String, dynamic> j) => GatewayCheckout(
        intentId: (j['intentId'] as num).toInt(),
        provider: j['provider'] as String,
        providerOrderRef: j['providerOrderRef'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'INR',
        clientParams: ((j['clientParams'] as Map?) ?? const <String, dynamic>{})
            .cast<String, dynamic>(),
      );
}
