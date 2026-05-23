import 'dart:convert';
import 'dart:math';
import 'package:shopxy_customer/core/network/api_client.dart';
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

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._client);
  final ApiClient _client;

  Future<int> placeOrder({
    required List<({int productId, double quantity})> items,
    String? note,
    String? idempotencyKey,
  }) async {
    // Generate one if the caller didn't pass it in. A retry of the
    // *same* logical cart submit must reuse the *same* key — that's the
    // caller's responsibility; the default we mint here is per-call so
    // independent submits never collide.
    final key = idempotencyKey ?? _newIdempotencyKey();
    final res = await _client.post(
      '/me/orders',
      extraHeaders: {'X-Idempotency-Key': key},
      body: {
        'items': items
            .map((i) => {'productId': i.productId, 'quantity': i.quantity})
            .toList(),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Order failed');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['id'] as int;
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

  Future<void> cancel(int id) async {
    final res = await _client.post('/me/orders/$id/cancel');
    if (res.statusCode == 204) return;
    // Backend returns `{ error, code }` on failure (code is one of
    // NOT_FOUND / NOT_OWNED / NOT_PENDING). Surface both so the caller
    // can pick targeted copy.
    String code = 'UNKNOWN';
    String message = 'Could not cancel order';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      code = (body['code'] as String?) ?? code;
      message = (body['error'] as String?) ?? message;
    } catch (_) {/* keep defaults */}
    throw CancelOrderException(code, message);
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
}
