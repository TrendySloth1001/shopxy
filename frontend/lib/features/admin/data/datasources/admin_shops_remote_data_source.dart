import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';

/// Adapter for `/admin/shops` (gated upstream by requirePlatformAdmin).
/// Today it surfaces the verified-toggle; future iterations can add
/// suspension, takedown, and review history here without changing the
/// page shape.
class AdminShopsRemoteDataSource {
  AdminShopsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<AdminShopRow>> list({String? search}) async {
    final res = await _client.get(
      '/admin/shops',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load shops: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ((body['data'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AdminShopRow.fromJson)
        .toList();
  }

  Future<AdminShopRow> setVerified(int id, bool isVerified) async {
    final res = await _client.post(
      '/admin/shops/$id/verified',
      body: {'isVerified': isVerified},
    );
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.body}');
    }
    return AdminShopRow.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class AdminShopRow {
  const AdminShopRow({
    required this.id,
    required this.name,
    required this.slug,
    required this.isVerified,
    required this.isPublished,
    this.logoUrl,
    this.locationCity,
    this.locationState,
    this.rating,
    this.ratingCount = 0,
  });

  final int id;
  final String name;
  final String slug;
  final bool isVerified;
  final bool isPublished;
  final String? logoUrl;
  final String? locationCity;
  final String? locationState;
  final double? rating;
  final int ratingCount;

  factory AdminShopRow.fromJson(Map<String, dynamic> j) => AdminShopRow(
        id: (j['id'] as num).toInt(),
        name: (j['name'] as String?) ?? '—',
        slug: (j['slug'] as String?) ?? '',
        isVerified: (j['isVerified'] as bool?) ?? false,
        isPublished: (j['isPublished'] as bool?) ?? false,
        logoUrl: j['logoUrl'] as String?,
        locationCity: j['locationCity'] as String?,
        locationState: j['locationState'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['ratingCount'] as num?)?.toInt() ?? 0,
      );
}
