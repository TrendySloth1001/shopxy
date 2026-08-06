import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/pdf_templates/domain/entities/pdf_template.dart';

void _expectOk(http.Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  try {
    final body = jsonDecode(response.body);
    if (body is Map && body['error'] is String) {
      throw Exception(body['error']);
    }
  } catch (_) {
    // fall through to the generic message
  }
  throw Exception(
    'Request failed (${response.statusCode}): ${response.body}',
  );
}

class PdfTemplatesRemoteDataSource {
  const PdfTemplatesRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<PdfTemplate>> list() async {
    final response = await _client.get('/pdf-templates');
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => PdfTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Raw PDF bytes for a canned sample document in [templateId] — used by
  /// the "Preview" action so a merchant can see a template before picking
  /// it, without needing an in-app PDF viewer (handed off to the OS the
  /// same way a real invoice download is).
  Future<http.Response> sample(String templateId, {String kind = 'invoice'}) {
    return _client.get('/pdf-templates/$templateId/sample?kind=$kind');
  }
}
