import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/reviews/data/models/product_review.dart';

class ReviewsRemoteDataSource {
  ReviewsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<ReviewsPage> list(int productId, {int? cursor, int limit = 20}) async {
    final query = <String, String>{'limit': '$limit'};
    if (cursor != null) query['cursor'] = '$cursor';
    final res = await _client.get('/products/$productId/reviews', queryParameters: query);
    if (res.statusCode != 200) {
      throw Exception('Failed to load reviews: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>)
        .map((e) => ProductReview.fromJson(e as Map<String, dynamic>))
        .toList();
    return ReviewsPage(data: data, nextCursor: body['nextCursor'] as int?);
  }

  /// One-shot summary for the product detail page: average, count,
  /// verified-buyer count, per-star histogram and the most recent
  /// reviews — no follow-up list call needed.
  Future<ReviewSummary> summary(int productId) async {
    final res = await _client.get('/products/$productId/reviews/summary');
    if (res.statusCode != 200) {
      throw Exception('Failed to load review summary: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ReviewSummary.fromJson(body);
  }
}
