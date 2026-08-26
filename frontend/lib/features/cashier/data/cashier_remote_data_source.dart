import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/api_client.dart';

class CashierRemoteDataSource {
  const CashierRemoteDataSource(this._client);
  final ApiClient _client;

  Map<String, dynamic> _ok(http.Response r) {
    final dynamic body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final msg = (body is Map && body['error'] is String) ? body['error'] as String : 'Request failed (${r.statusCode})';
      throw Exception(msg);
    }
    return (body as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> current() async => _ok(await _client.get('/me/cashier/current'));

  Future<void> openShift(double openingFloat) async {
    _ok(await _client.post('/me/cashier/shift/open', body: {'openingFloat': openingFloat}));
  }

  Future<Map<String, dynamic>> cashMovement(String type, double amount, String? reason) async =>
      _ok(await _client.post('/me/cashier/cash-movement', body: {
            'type': type,
            'amount': amount,
            if (reason != null && reason.isNotEmpty) 'reason': reason,
          }));

  Future<Map<String, dynamic>> closeShift(double countedCash, String? note) async =>
      _ok(await _client.post('/me/cashier/shift/close', body: {
            'countedCash': countedCash,
            if (note != null && note.isNotEmpty) 'note': note,
          }));

  Future<List<Map<String, dynamic>>> listShifts() async {
    final r = await _client.get('/me/cashier/shifts');
    final dynamic body = r.body.isEmpty ? [] : jsonDecode(r.body);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Could not load shift history (${r.statusCode})');
    }
    return body is List ? body.cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> shiftReport(String shiftId) async =>
      _ok(await _client.get('/me/cashier/shifts/$shiftId/report'));

  Future<Map<String, dynamic>> returnable(String invoiceId) async =>
      _ok(await _client.get('/me/cashier/returnable/$invoiceId'));

  Future<Map<String, dynamic>> processReturn({
    required String originalInvoiceId,
    required String refundMode,
    required List<Map<String, dynamic>> lines,
  }) async =>
      _ok(await _client.post('/me/cashier/return', body: {
            'originalInvoiceId': originalInvoiceId,
            'refundMode': refundMode,
            'lines': lines,
          }));
}
