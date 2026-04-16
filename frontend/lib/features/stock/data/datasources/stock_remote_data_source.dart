import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/stock/data/models/stock_transaction_dto.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';

class StockRemoteDataSource {
  const StockRemoteDataSource(this._client);
  final ApiClient _client;

  Future<StockTransaction> createTransaction(Map<String, dynamic> data) async {
    final response = await _client.post('/stock', body: data);
    return StockTransactionDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<StockTransaction>> getTransactions({
    int? productId,
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
}
