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

    final drafts = json['draftInvoices'] as Map<String, dynamic>?;
    final recentDrafts = ((drafts?['recent'] as List?) ?? const [])
        .map((e) => _draftFromJson(e as Map<String, dynamic>))
        .toList();

    return DashboardStats(
      totalProducts: json['totalProducts'] as int,
      activeProducts: json['activeProducts'] as int,
      totalCategories: json['totalCategories'] as int,
      lowStockCount: json['lowStockCount'] as int,
      outOfStockCount: json['outOfStockCount'] as int,
      totalStockValue: (json['totalStockValue'] as num).toDouble(),
      recentTransactions: transactions,
      draftInvoiceCount: (drafts?['count'] as int?) ?? 0,
      recentDrafts: recentDrafts,
    );
  }

  static DashboardDraftInvoice _draftFromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final type = json['type'] as String;
    final counterparty = type == 'SALE'
        ? (json['customerName'] as String? ?? 'Walk-in Customer')
        : (json['vendorName'] as String? ?? 'Unknown vendor');
    return DashboardDraftInvoice(
      id: json['id'] as int,
      invoiceNo: json['invoiceNo'] as String,
      type: type,
      total: (json['total'] is num)
          ? (json['total'] as num).toDouble()
          : double.tryParse('${json['total']}') ?? 0,
      itemCount: (count?['items'] as int?) ?? 0,
      counterpartyName: counterparty,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
