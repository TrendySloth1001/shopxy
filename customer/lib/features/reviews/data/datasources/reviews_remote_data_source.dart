import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/reviews/domain/entities/review.dart';

class ReviewsRemoteDataSource {
  ReviewsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<ReviewSummary> getSummary(String productId) async {
    final res = await _client.get('/products/$productId/reviews/summary');
    if (res.statusCode != 200) {
      throw Exception('Failed to load review summary: ${res.body}');
    }
    return ReviewSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ReviewsPage> list(String productId, {int? cursor, int limit = 20}) async {
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = '$cursor';
    final res = await _client.get(
      '/products/$productId/reviews',
      queryParameters: params,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load reviews: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ReviewsPage(
      data: (body['data'] as List<dynamic>)
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (body['nextCursor'] as num?)?.toInt(),
    );
  }

  Future<Review> upsert(
    String productId, {
    required int rating,
    String? title,
    String? body,
  }) async {
    final payload = <String, dynamic>{
      'rating': rating,
      if (title != null && title.isNotEmpty) 'title': title,
      if (body != null && body.isNotEmpty) 'body': body,
    };
    final res = await _client.post(
      '/products/$productId/reviews',
      body: payload,
    );
    if (res.statusCode != 200) {
      throw _reviewWriteException(res.statusCode, res.body);
    }
    return Review.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteMine(String productId) async {
    final res = await _client.delete('/products/$productId/reviews/mine');
    if (res.statusCode != 204 && res.statusCode != 404) {
      throw Exception('Delete failed: ${res.body}');
    }
  }

  Future<MyReviewsPage> listMine({int? cursor, int limit = 20}) async {
    final params = <String, String>{'limit': '$limit'};
    if (cursor != null) params['cursor'] = '$cursor';
    final res = await _client.get('/me/reviews', queryParameters: params);
    if (res.statusCode != 200) {
      throw Exception('Failed to load your reviews: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return MyReviewsPage(
      data: ((body['data'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MyReview.fromJson)
          .toList(),
      nextCursor: (body['nextCursor'] as num?)?.toInt(),
    );
  }
}

class ReviewWriteException implements Exception {
  ReviewWriteException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

ReviewWriteException _reviewWriteException(int status, String raw) {
  String message = raw;
  try {
    final body = jsonDecode(raw) as Map<String, dynamic>;
    if (body['error'] is String) message = body['error'] as String;
  } catch (_) {
  }
  return ReviewWriteException(status, message);
}
