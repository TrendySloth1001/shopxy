import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';

class CancelOrderException implements Exception {
  CancelOrderException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

class PriceDrift {
  const PriceDrift({
    required this.productId,
    required this.expectedUnitPrice,
    required this.actualUnitPrice,
  });
  final String productId;
  final double expectedUnitPrice;
  final double actualUnitPrice;
}

class PriceDriftException implements Exception {
  PriceDriftException(this.drifts);
  final List<PriceDrift> drifts;

  @override
  String toString() => 'Prices have changed since you viewed the cart.';
}

class PlaceOrderResponse {
  const PlaceOrderResponse({required this.orderId, required this.shopOrders});
  final String orderId;
  final List<({String id, String shopId})> shopOrders;
}

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._client);
  final ApiClient _client;

  Future<PlaceOrderResponse> placeOrder({
    required List<({String productId, double quantity, double? expectedUnitPrice})>
        items,
    String? note,
    String? idempotencyKey,
    String? addressId,
    String? couponCode,
    bool claimGst = false,
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
        if (claimGst) 'claimGst': true,
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 409 && err['error'] == 'PRICE_DRIFT') {
        final details = ((err['details'] as List?) ?? const [])
            .map((e) {
              final m = e as Map<String, dynamic>;
              return PriceDrift(
                productId: m['productId'].toString(),
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
          return (id: m['id'].toString(), shopId: m['shopId'].toString());
        })
        .toList(growable: false);
    return PlaceOrderResponse(
      orderId: json['id'].toString(),
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

  Future<CustomerOrderDetail> detail(String id) async {
    final res = await _client.get('/me/orders/$id');
    if (res.statusCode != 200) throw Exception('Order not found');
    return CustomerOrderDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> cancelShopOrder({
    required String parentId,
    required String childId,
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
    } catch (_) {}
    throw CancelOrderException(code, message);
  }

  Future<({List<({CatalogProduct product, double quantity})> items,
          List<({String productId, String productName, String reason})> skipped})>
      reorder(String parentId) async {
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
              productId: m['productId'].toString(),
              productName: (m['productName'] as String?) ?? '',
              reason: (m['reason'] as String?) ?? 'UNAVAILABLE',
            ))
        .toList();
    return (items: items, skipped: skipped);
  }

  Future<Uint8List> downloadInvoicePdf({
    required String parentId,
    required String childId,
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

  static String _newIdempotencyKey() {
    final r = Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    final s = '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
    return s;
  }

  Future<GatewayCheckout> payForOrder(String orderId) async {
    final res = await _client.post('/me/orders/$orderId/pay');
    if (res.statusCode != 201) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Could not start payment');
    }
    return GatewayCheckout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<String> syncOrderPayment(String orderId) async {
    final res = await _client.post('/me/orders/$orderId/payment/sync');
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Could not sync payment');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['paymentStatus'] as String?) ?? 'PENDING';
  }
}

class GatewayCheckout {
  const GatewayCheckout({
    required this.intentId,
    required this.provider,
    required this.providerOrderRef,
    required this.amount,
    required this.currency,
    required this.clientParams,
  });

  final String intentId;
  final String provider;
  final String providerOrderRef;
  final double amount;
  final String currency;
  final Map<String, dynamic> clientParams;

  factory GatewayCheckout.fromJson(Map<String, dynamic> j) => GatewayCheckout(
        intentId: j['intentId'].toString(),
        provider: j['provider'] as String,
        providerOrderRef: j['providerOrderRef'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'INR',
        clientParams: ((j['clientParams'] as Map?) ?? const <String, dynamic>{})
            .cast<String, dynamic>(),
      );
}
