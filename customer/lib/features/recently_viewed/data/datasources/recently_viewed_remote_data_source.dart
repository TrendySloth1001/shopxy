import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_models.dart';
import 'package:shopxy_customer/features/recently_viewed/data/recently_viewed_mapper.dart';

/// Adapter for the per-user "recently viewed" surface.
///
///   GET /me/recently-viewed → { data: [{ id, lastViewedAt, product: {...} }] }
///
/// Backend caps the list at 20 rows per user; an hourly cron trims older
/// entries so this endpoint never returns more than that.
class RecentlyViewedRemoteDataSource {
  const RecentlyViewedRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<ProductCard>> list() async {
    final res = await _client.get('/me/recently-viewed');
    if (res.statusCode != 200) {
      throw Exception('Failed to load recently viewed: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (json['data'] as List<dynamic>?) ?? const [];
    return rows
        .map((r) => RecentlyViewedMapper.fromRow(r as Map<String, dynamic>))
        .whereType<ProductCard>()
        .toList();
  }
}
