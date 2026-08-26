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
}
