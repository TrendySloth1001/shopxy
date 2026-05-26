import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/reviews/domain/entities/review.dart';

/// HTTP wrapper around /products/:id/reviews + /summary. Stays thin —
/// no caching, no provider — so individual pages can decide how to
/// surface errors and pagination state.
class ReviewsRemoteDataSource {
  ReviewsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<ReviewSummary> getSummary(int productId) async {
    final res = await _client.get('/products/$productId/reviews/summary');
    if (res.statusCode != 200) {
      throw Exception('Failed to load review summary: ${res.body}');
    }
    return ReviewSummary.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ReviewsPage> list(int productId, {int? cursor, int limit = 20}) async {
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

  /// Returns the updated review on 200, throws with the server message
  /// on any other status. The "only buyers" 403 case carries a
  /// readable `error` string the caller surfaces directly.
  Future<Review> upsert(
    int productId, {
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

  Future<void> deleteMine(int productId) async {
    final res = await _client.delete('/products/$productId/reviews/mine');
    if (res.statusCode != 204 && res.statusCode != 404) {
      throw Exception('Delete failed: ${res.body}');
    }
  }
}

/// Carries the server message + status so the write-review sheet can
/// distinguish "not purchased" (403) from "invalid rating" (400) and
/// from generic transport errors. Plain Exception otherwise loses the
/// status code by the time it reaches the snackbar.
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
    // not JSON — fall through with raw
  }
  return ReviewWriteException(status, message);
}
