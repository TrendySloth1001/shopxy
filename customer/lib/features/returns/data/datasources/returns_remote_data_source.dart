import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/returns/domain/return_request.dart';

/// Adapter for the customer-side returns endpoints.
///
///   POST /me/orders/:parentId/returns      — submit
///   GET  /me/returns?page=&limit=          — list
///   GET  /me/returns/:id                   — detail
///   POST /me/returns/:id/cancel            — cancel (REQUESTED only)
class ReturnsRemoteDataSource {
  const ReturnsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<int> submit({
    required int parentOrderId,
    required int shopOrderId,
    required List<({int purchaseRequestItemId, double quantity, String reason})> items,
    String? note,
  }) async {
    final res = await _client.post(
      '/me/orders/$parentOrderId/returns',
      body: {
        'childId': shopOrderId,
        if (note != null && note.isNotEmpty) 'note': note,
        'items': items
            .map((i) => {
                  'purchaseRequestItemId': i.purchaseRequestItemId,
                  'quantity': i.quantity,
                  'reason': i.reason,
                })
            .toList(),
      },
    );
    if (res.statusCode != 201) {
      final body = _decodeError(res.body);
      throw Exception(body);
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['id'] as int;
  }

  Future<List<ReturnRequest>> list({int page = 1, int limit = 30}) async {
    final res = await _client.get(
      '/me/returns',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load returns (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return ((json['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReturnRequest.fromJson)
        .toList();
  }

  Future<ReturnRequest> getById(int id) async {
    final res = await _client.get('/me/returns/$id');
    if (res.statusCode == 404) throw Exception('Return not found');
    if (res.statusCode != 200) {
      throw Exception('Failed to load return (${res.statusCode})');
    }
    return ReturnRequest.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<void> cancel(int id) async {
    final res = await _client.post('/me/returns/$id/cancel');
    if (res.statusCode == 204) return;
    throw Exception(_decodeError(res.body));
  }

  String _decodeError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      final raw = (m['error'] as String?) ?? 'Request failed';
      return _humaniseErrorCode(raw);
    } catch (_) {
      return 'Request failed';
    }
  }

  String _humaniseErrorCode(String code) {
    switch (code) {
      case 'NOT_FOUND':
        return 'Return not found';
      case 'NOT_DELIVERED':
        return 'This order can\'t be returned yet';
      case 'INVALID_ITEMS':
        return 'Pick at least one item to return';
      case 'BAD_QTY':
        return 'You can\'t return more than you ordered';
      case 'ALREADY_REQUESTED':
        return 'You\'ve already opened a return for this order';
      default:
        return code;
    }
  }
}
