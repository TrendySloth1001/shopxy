import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/returns/domain/merchant_return.dart';

/// Adapter for the merchant-side returns endpoints.
///
///   GET    /orders/returns?status=&page=&limit=   — list (status optional)
///   GET    /orders/returns/:id                    — detail
///   POST   /orders/returns/:id/approve
///   POST   /orders/returns/:id/reject
///   POST   /orders/returns/:id/picked-up
///   POST   /orders/returns/:id/received
///   POST   /orders/returns/:id/refund
class MerchantReturnsRemoteDataSource {
  const MerchantReturnsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<({List<MerchantReturn> data, int total})> list({
    String? status,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _client.get('/orders/returns', queryParameters: {
      'page': '$page',
      'limit': '$limit',
      if (status != null && status.isNotEmpty) 'status': status,
    });
    if (res.statusCode != 200) {
      throw Exception('Failed to load returns (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = ((json['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MerchantReturn.fromJson)
        .toList();
    final total = (json['pagination'] as Map?)?['total'] as int? ?? rows.length;
    return (data: rows, total: total);
  }

  Future<MerchantReturn> getById(int id) async {
    final res = await _client.get('/orders/returns/$id');
    if (res.statusCode != 200) throw Exception('Return not found');
    return MerchantReturn.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// Generic transition POST — all four state-flip endpoints share the
  /// same `{ note?: string }` body and 204 / 409 shape.
  Future<void> _transition(int id, String action, {String? note}) async {
    final res = await _client.post(
      '/orders/returns/$id/$action',
      body: {
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (res.statusCode == 204) return;
    throw Exception(_decodeError(res.body));
  }

  Future<void> approve(int id, {String? note}) => _transition(id, 'approve', note: note);
  Future<void> reject(int id, {String? note}) => _transition(id, 'reject', note: note);
  Future<void> markPickedUp(int id, {String? note}) =>
      _transition(id, 'picked-up', note: note);
  Future<void> markReceived(int id, {String? note}) =>
      _transition(id, 'received', note: note);

  /// Refund returns `{ ok, refundAmount, refundStatus }`. The money goes back
  /// to the buyer's ORIGINAL payment instrument (card/UPI/netbanking) via the
  /// gateway — never wallet/store credit. `refundStatus` is REFUNDED |
  /// NO_PAYMENT (COD/never captured — merchant settles offline) | FAILED |
  /// NOTHING_TO_REFUND.
  Future<({double refundAmount, String refundStatus})> refund(
    int id, {
    String? note,
  }) async {
    final res = await _client.post(
      '/orders/returns/$id/refund',
      body: {
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (res.statusCode != 200) throw Exception(_decodeError(res.body));
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      refundAmount: (m['refundAmount'] as num).toDouble(),
      refundStatus: (m['refundStatus'] as String?) ?? 'NO_PAYMENT',
    );
  }

  String _decodeError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      final code = (m['error'] as String?) ?? 'Request failed';
      switch (code) {
        case 'NOT_FOUND':
          return 'Return not found';
        case 'BAD_STATE':
          return 'This return can\'t move to that state from where it is.';
        default:
          return code;
      }
    } catch (_) {
      return 'Request failed';
    }
  }
}
