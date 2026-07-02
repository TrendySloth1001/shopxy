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

  /// Aggregated "products sold" summary — one row per product, biggest revenue
  /// first, optionally filtered by a product name / SKU [search].
  Future<SoldProductsPage> soldProducts(
    DateTime from,
    DateTime to, {
    int page = 1,
    int limit = 25,
    String search = '',
  }) async {
    final params = _range(from, to)
      ..['page'] = page.toString()
      ..['limit'] = limit.toString();
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    final res =
        await _client.get('/reports/sold-products', queryParameters: params);
    if (res.statusCode != 200) {
      throw Exception('Failed to load sold products: ${res.statusCode}');
    }
    return SoldProductsPage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// One page of a single product's sale timeline (newest first).
  Future<SoldItemsPage> soldItems(
    DateTime from,
    DateTime to, {
    required int productId,
    int page = 1,
    int limit = 15,
  }) async {
    final params = _range(from, to)
      ..['productId'] = productId.toString()
      ..['page'] = page.toString()
      ..['limit'] = limit.toString();
    final res =
        await _client.get('/reports/sold-items', queryParameters: params);
    if (res.statusCode != 200) {
      throw Exception('Failed to load sale timeline: ${res.statusCode}');
    }
    return SoldItemsPage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
