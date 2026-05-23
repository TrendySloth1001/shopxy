import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';

class OrdersRemoteDataSource {
  const OrdersRemoteDataSource(this._client);
  final ApiClient _client;

  Future<int> placeOrder({
    required List<({int productId, double quantity})> items,
    String? note,
  }) async {
    final res = await _client.post('/me/orders', body: {
      'items': items
          .map((i) => {'productId': i.productId, 'quantity': i.quantity})
          .toList(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    if (res.statusCode != 201) {
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
      throw Exception('Failed to load orders: ${res.statusCode}');
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
    if (res.statusCode != 204) {
      throw Exception('Could not cancel');
    }
  }
}
