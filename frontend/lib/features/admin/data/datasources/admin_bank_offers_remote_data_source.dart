import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/admin/data/models/platform_bank_offer.dart';

/// Adapter for `/admin/platform-bank-offers` — gated upstream by
/// `requirePlatformAdmin`. Mirrors the banners admin shape so the
/// page + provider pattern is reusable. No pagination yet — the
/// surface is admin-only and the row count is small (≤ tens).
class AdminBankOffersRemoteDataSource {
  AdminBankOffersRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<AdminPlatformBankOffer>> list() async {
    final res = await _client.get('/admin/platform-bank-offers');
    if (res.statusCode != 200) {
      throw Exception('Failed to load bank offers: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['data'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AdminPlatformBankOffer.fromJson)
        .toList();
  }

  Future<AdminPlatformBankOffer> create(Map<String, dynamic> body) async {
    final res = await _client.post('/admin/platform-bank-offers', body: body);
    if (res.statusCode != 201) {
      throw Exception('Create failed: ${res.body}');
    }
    return AdminPlatformBankOffer.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<AdminPlatformBankOffer> update(
    int id,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.patch(
      '/admin/platform-bank-offers/$id',
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.body}');
    }
    return AdminPlatformBankOffer.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<void> deactivate(int id) async {
    final res = await _client.delete('/admin/platform-bank-offers/$id');
    if (res.statusCode != 204) {
      throw Exception('Deactivate failed: ${res.body}');
    }
  }
}
