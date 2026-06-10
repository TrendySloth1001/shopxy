import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/orders/domain/entities/merchant_order.dart';

/// Surfaces the 409 INSUFFICIENT_STOCK detail (productId / available /
/// requested) without losing it in a generic Exception string. The
/// detail page uses these fields to highlight the offending line.
class OrderConfirmException implements Exception {
  OrderConfirmException({
    required this.code,
    required this.message,
    this.productId,
    this.available,
    this.requested,
  });

  final String code;
  final String message;
  final int? productId;
  final double? available;
  final double? requested;

  @override
  String toString() => message;
}

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._client);
  final ApiClient _client;

  Future<({List<MerchantOrder> data, int total})> list({
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _client.get('/orders', queryParameters: {
      'page': '$page',
      'limit': '$limit',
      'status': ?status,
      'search': ?(search != null && search.isNotEmpty ? search : null),
      'from': ?from?.toUtc().toIso8601String(),
      'to': ?to?.toUtc().toIso8601String(),
    });
    if (res.statusCode != 200) {
      throw Exception('Failed to load orders: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (json['data'] as List)
        .map((e) => MerchantOrder.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (json['pagination'] as Map?)?['total'] as int? ?? list.length;
    return (data: list, total: total);
  }

  Future<int> pendingCount() async {
    final res = await _client.get('/orders/pending-count');
    if (res.statusCode != 200) return 0;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['count'] as int? ?? 0;
  }

  Future<MerchantOrderDetail> detail(int id) async {
    final res = await _client.get('/orders/$id');
    if (res.statusCode != 200) throw Exception('Order not found');
    return MerchantOrderDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<({int invoiceId, String invoiceNo})> confirm(int id, {String? note}) async {
    final res = await _client.post('/orders/$id/confirm', body: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final inv = json['invoice'] as Map<String, dynamic>;
      return (invoiceId: inv['id'] as int, invoiceNo: inv['invoiceNo'] as String);
    }
    Map<String, dynamic> body = const {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {/* keep empty */}
    final code = (body['error'] as String?) ?? 'CONFIRM_FAILED';
    final message = _confirmMessageForCode(code, body);
    throw OrderConfirmException(
      code: code,
      message: message,
      productId: body['productId'] as int?,
      available: _maybeDouble(body['available']),
      requested: _maybeDouble(body['requested']),
    );
  }

  /// Record a shipping milestone (PACKED / SHIPPED / OUT_FOR_DELIVERY /
  /// DELIVERED / RETURNED) against a confirmed order. Same route +
  /// payload merchant-web uses: POST /orders/:id/events.
  Future<void> addShippingEvent(
    int id, {
    required String type,
    String? courier,
    String? awb,
    DateTime? eta,
    String? note,
  }) async {
    final res = await _client.post('/orders/$id/events', body: {
      'type': type,
      if (courier != null && courier.isNotEmpty) 'courier': courier,
      if (awb != null && awb.isNotEmpty) 'awb': awb,
      // Backend validates with z.string().datetime() — send UTC ISO.
      if (eta != null) 'eta': eta.toUtc().toIso8601String(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    if (res.statusCode == 201) return;
    Map<String, dynamic> body = const {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {/* keep empty */}
    throw Exception(
      body['error']?.toString() ?? 'Could not update shipping',
    );
  }

  Future<void> reject(int id, {String? note}) async {
    final res = await _client.post('/orders/$id/reject', body: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
    if (res.statusCode != 204) {
      throw Exception('Failed to reject');
    }
  }

  static String _confirmMessageForCode(String code, Map<String, dynamic> body) {
    switch (code) {
      case 'INSUFFICIENT_STOCK':
        return 'Not enough stock to fulfil this order';
      case 'NOT_FOUND':
        return 'Order not found';
      case 'NOT_PENDING':
        return 'This order is no longer pending';
      case 'NO_ITEMS':
        return 'Order has no items';
      default:
        // Fall back to whatever the server sent, even if it was a
        // domain error string from the invoices service.
        return body['error']?.toString() ?? 'Failed to confirm order';
    }
  }

  static double? _maybeDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
