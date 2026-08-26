import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/banner_detail/domain/entities/banner_detail.dart';

class BannerDetailRemoteDataSource {
  const BannerDetailRemoteDataSource(this._client);
  final ApiClient _client;

  Future<BannerDetail> fetchBannerDetail(String id) async {
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
