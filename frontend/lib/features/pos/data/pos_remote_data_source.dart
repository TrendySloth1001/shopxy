import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/pos/data/pos_models.dart';

/// REST side of the POS till. Every mutation returns the fresh server snapshot
/// (the cart is server-authoritative); the WebSocket delivers changes made on
/// the other till.
class PosRemoteDataSource {
  const PosRemoteDataSource(this._client);
  final ApiClient _client;

  static void _ok(http.Response r, String action) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {}
      throw Exception(body?['error'] ?? '$action failed (${r.statusCode})');
    }
  }

  SaleSnapshot _snap(http.Response r, String action) {
    _ok(r, action);
    return SaleSnapshot.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<SaleSnapshot> openSale() async {
    final r = await _client.post('/me/pos/sales', body: {});
    return _snap(r, 'Open sale');
  }

  Future<SaleSnapshot> getSale(int saleId) async {
    final r = await _client.get('/me/pos/sales/$saleId');
    return _snap(r, 'Load sale');
  }

  /// Scan a code: resolved + added to the shared cart, or unknown.
  Future<ScanOutcome> scan(int saleId, String code) async {
    final r = await _client.post('/me/pos/sales/$saleId/scan', body: {'code': code});
    _ok(r, 'Scan');
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (body['unknown'] == true) return ScanOutcome(unknownCode: body['code'] as String?);
    return ScanOutcome(snapshot: SaleSnapshot.fromJson(body));
  }

  /// Quick-add a new product (from an unknown scan) and add it to the cart.
  Future<SaleSnapshot> quickAdd(
    int saleId, {
    required String code,
    required String name,
    required double sellingPrice,
    double? taxPercent,
    double? openingStock,
  }) async {
    final r = await _client.post('/me/pos/sales/$saleId/quick-add', body: {
      'code': code,
      'name': name,
      'sellingPrice': sellingPrice,
      'taxPercent': ?taxPercent,
      'openingStock': ?openingStock,
    });
    return _snap(r, 'Quick add');
  }

  Future<SaleSnapshot> setQty(int saleId, int productId, double quantity) async {
    final r = await _client.patch('/me/pos/sales/$saleId/items/$productId', body: {'quantity': quantity});
    return _snap(r, 'Update quantity');
  }

  Future<SaleSnapshot> removeItem(int saleId, int productId) async {
    final r = await _client.delete('/me/pos/sales/$saleId/items/$productId');
    return _snap(r, 'Remove item');
  }

  /// Single-transaction checkout → confirmed invoice + receipt. Returns the
  /// invoice number for the receipt.
  Future<String> checkout(int saleId, String mode) async {
    final r = await _client.post('/me/pos/sales/$saleId/checkout', body: {
      'tender': {'mode': mode},
    });
    _ok(r, 'Checkout');
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final invoice = body['invoice'] as Map<String, dynamic>?;
    return (invoice?['invoiceNo'] as String?) ?? '—';
  }
}
