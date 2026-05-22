import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/reports/domain/entities/sales_report.dart';

class ReportsRemoteDataSource {
  const ReportsRemoteDataSource(this._client);
  final ApiClient _client;

  Map<String, String> _range(DateTime from, DateTime to) => {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      };

  Future<SalesReport> sales(DateTime from, DateTime to) async {
    final res = await _client.get('/reports/sales', queryParameters: _range(from, to));
    if (res.statusCode != 200) {
      throw Exception('Failed to load sales report: ${res.statusCode}');
    }
    return SalesReport.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<PurchasesReport> purchases(DateTime from, DateTime to) async {
    final res = await _client.get('/reports/purchases', queryParameters: _range(from, to));
    if (res.statusCode != 200) {
      throw Exception('Failed to load purchases report: ${res.statusCode}');
    }
    return PurchasesReport.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<GstReport> gst(DateTime from, DateTime to) async {
    final res = await _client.get('/reports/gst', queryParameters: _range(from, to));
    if (res.statusCode != 200) {
      throw Exception('Failed to load GST report: ${res.statusCode}');
    }
    return GstReport.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<PnlReport> pnl(DateTime from, DateTime to) async {
    final res = await _client.get('/reports/pnl', queryParameters: _range(from, to));
    if (res.statusCode != 200) {
      throw Exception('Failed to load P&L report: ${res.statusCode}');
    }
    return PnlReport.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
