import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/stock/data/models/stock_transaction_dto.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';

class SupplierVendor {
  const SupplierVendor({required this.id, required this.name, this.phone});

  final String id;
  final String name;
  final String? phone;

  factory SupplierVendor.fromJson(Map<String, dynamic> j) => SupplierVendor(
        id: j['id'].toString(),
        name: j['name'] as String,
        phone: j['phone'] as String?,
      );
}

class StockRemoteDataSource {
  const StockRemoteDataSource(this._client);
  final ApiClient _client;

  /// Manual stock-in/out now creates a DRAFT invoice instead of posting
  /// directly. Returns the draft invoice id so callers can navigate to it.
  Future<String> createTransaction(Map<String, dynamic> data) async {
    final response = await _client.post('/stock', body: data);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final draft = body['draftInvoice'] as Map<String, dynamic>?;
    if (draft == null) {
      throw Exception('Backend did not return a draft invoice');
    }
    return draft['id'].toString();
  }

  Future<List<StockTransaction>> getTransactions({
    String? productId,
    String? type,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (productId != null) params['productId'] = productId.toString();
    if (type != null) params['type'] = type;

    final response = await _client.get('/stock', queryParameters: params);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    return data
        .map((e) => StockTransactionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({List<SupplierVendor> vendors, List<String> freeTextSuppliers})> getSuppliers({
    String? query,
    String? productId,
    int limit = 12,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (productId != null) params['productId'] = productId.toString();

    final response = await _client.get('/stock/suppliers', queryParameters: params);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final vendorsList = (body['vendors'] as List<dynamic>? ?? [])
        .map((e) => SupplierVendor.fromJson(e as Map<String, dynamic>))
        .toList();
    final freeText = (body['freeTextSuppliers'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    return (vendors: vendorsList, freeTextSuppliers: freeText);
  }
}
