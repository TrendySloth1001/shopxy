import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/invoice_numbering/domain/entities/numbering_scheme.dart';

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

class InvoiceNumberingRemoteDataSource {
  const InvoiceNumberingRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<NumberingScheme>> list() async {
    final response = await _client.get('/numbering');
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => NumberingScheme.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NumberingScheme> update(
    NumberingSeries series,
    Map<String, dynamic> patch,
  ) async {
    final response = await _client.patch(
      '/numbering/${series.wire}',
      body: patch,
    );
    _expectOk(response);
    return NumberingScheme.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<NumberingScheme> setNextNumber(
    NumberingSeries series,
    int startAt,
  ) async {
    final response = await _client.post(
      '/numbering/${series.wire}/next-number',
      body: {'startAt': startAt},
    );
    _expectOk(response);
    return NumberingScheme.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
