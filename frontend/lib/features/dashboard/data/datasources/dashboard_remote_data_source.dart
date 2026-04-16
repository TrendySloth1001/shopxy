import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/stock/data/models/stock_transaction_dto.dart';

class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._client);
  final ApiClient _client;

  Future<DashboardStats> getStats() async {
    final response = await _client.get('/dashboard/stats');
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final transactions = (json['recentTransactions'] as List)
        .map((e) => StockTransactionDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return DashboardStats(
      totalProducts: json['totalProducts'] as int,
      activeProducts: json['activeProducts'] as int,
      totalCategories: json['totalCategories'] as int,
      lowStockCount: json['lowStockCount'] as int,
      outOfStockCount: json['outOfStockCount'] as int,
      totalStockValue: (json['totalStockValue'] as num).toDouble(),
      recentTransactions: transactions,
    );
  }
}
