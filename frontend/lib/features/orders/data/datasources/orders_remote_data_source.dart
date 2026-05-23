import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/orders/domain/entities/merchant_order.dart';

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._client);
  final ApiClient _client;

  Future<({List<MerchantOrder> data, int total})> list({
    String? status,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _client.get('/orders', queryParameters: {
      'page': '$page',
      'limit': '$limit',
      'status': ?status,
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
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(err['error'] ?? 'Failed to confirm');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final inv = json['invoice'] as Map<String, dynamic>;
    return (invoiceId: inv['id'] as int, invoiceNo: inv['invoiceNo'] as String);
  }

  Future<void> reject(int id, {String? note}) async {
    final res = await _client.post('/orders/$id/reject', body: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
    if (res.statusCode != 204) {
      throw Exception('Failed to reject');
    }
  }
}
