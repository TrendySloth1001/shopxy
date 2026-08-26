import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';

class QuotationsRemoteDataSource {
  const QuotationsRemoteDataSource(this._client);
  final ApiClient _client;

  String _err(String body, String fallback) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return (m['message'] ?? m['error'] ?? fallback) as String;
    } catch (_) {
      return fallback;
    }
  }

  Future<List<Quotation>> list({String? status, bool archived = false}) async {
    final res = await _client.get('/quotations', queryParameters: {
      'limit': '50',
      'status': ?status,
      if (archived) 'archived': 'true',
    });
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to load quotations'));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List)
        .map((e) => Quotation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Quotation> create({
    required String partyId,
    required List<Map<String, dynamic>> items,
    String? note,
    String? placeOfSupplyStateCode,
  }) async {
    final res = await _client.post('/quotations', body: {
      'partyId': partyId,
      'items': items,
      if (note != null && note.isNotEmpty) 'note': note,
      if (placeOfSupplyStateCode != null && placeOfSupplyStateCode.isNotEmpty)
        'placeOfSupplyStateCode': placeOfSupplyStateCode,
    });
    if (res.statusCode != 201) {
      throw Exception(_err(res.body, 'Failed to send quotation'));
    }
    return Quotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Quotation> get(String id) async {
    final res = await _client.get('/quotations/$id');
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to load quotation'));
    }
    return Quotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Quotation> cancel(String id) async {
    final res = await _client.post('/quotations/$id/cancel');
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to cancel quotation'));
    }
    return Quotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Quotation> setArchived(String id, bool archived) async {
    final res = await _client.post(
      '/quotations/$id/${archived ? 'archive' : 'unarchive'}',
    );
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to update the quotation'));
    }
    return Quotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Quotation> respond(
    String id, {
    required List<Map<String, dynamic>> items,
    String? note,
    String? placeOfSupplyStateCode,
  }) async {
    final res = await _client.post('/quotations/$id/respond', body: {
      'items': items,
      if (note != null && note.isNotEmpty) 'note': note,
      if (placeOfSupplyStateCode != null && placeOfSupplyStateCode.isNotEmpty)
        'placeOfSupplyStateCode': placeOfSupplyStateCode,
    });
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to send quotation'));
    }
    return Quotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<http.Response> downloadPdf(String id) {
    return _client.get('/quotations/$id/pdf');
  }

  Future<Quotation> declineRequest(String id, {String? declineNote}) async {
    final res = await _client.post('/quotations/$id/decline-request', body: {
      if (declineNote != null && declineNote.isNotEmpty)
        'declineNote': declineNote,
    });
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to decline request'));
    }
    return Quotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
