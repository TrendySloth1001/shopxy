import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/analytics/data/models/analytics.dart';

class AnalyticsRemoteDataSource {
  AnalyticsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<ProductAnalytics> getProducts({DateTime? from, DateTime? to}) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();
    final res = await _client.get('/me/analytics/products', queryParameters: query);
    if (res.statusCode != 200) {
      throw Exception('Failed to load analytics: ${res.body}');
    }
    return ProductAnalytics.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<FlashDealAnalytics> getFlashDeal(int id) async {
    final res = await _client.get('/me/analytics/flash-deals/$id');
    if (res.statusCode != 200) {
      throw Exception('Failed to load flash analytics: ${res.body}');
    }
    return FlashDealAnalytics.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}
