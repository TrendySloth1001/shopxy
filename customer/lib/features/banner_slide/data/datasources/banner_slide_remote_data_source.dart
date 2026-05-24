import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';

/// Thin wrapper around GET /banners/:id/slide. The response shape is
/// `{ banner: {...}, products: [{...product, discountPct, salePrice}] }`
/// — returned as-is to the page layer (no extra modelling), since
/// only the slide-detail UI consumes it.
class BannerSlideRemoteDataSource {
  BannerSlideRemoteDataSource(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>?> fetch(int bannerId) async {
    final res = await _client.get('/banners/$bannerId/slide');
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Failed to load slide: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
