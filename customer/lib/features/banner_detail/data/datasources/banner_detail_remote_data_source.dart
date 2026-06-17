import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/banner_detail/domain/entities/banner_detail.dart';

/// Network adapter for the public banner-detail endpoint.
///
///   GET /banners/:id
///
/// Open to anonymous callers — the shared [ApiClient] still forwards the
/// access token when present. Returns 404 when the banner isn't visible.
class BannerDetailRemoteDataSource {
  const BannerDetailRemoteDataSource(this._client);
  final ApiClient _client;

  Future<BannerDetail> fetchBannerDetail(int id) async {
    final res = await _client.get('/banners/$id');
    if (res.statusCode == 404) {
      throw Exception('Banner not found');
    }
    if (res.statusCode != 200) {
      throw Exception('Failed to load banner: ${res.statusCode}');
    }
    return BannerDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}
