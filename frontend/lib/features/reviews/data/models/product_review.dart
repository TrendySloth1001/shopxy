class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.rating,
    this.title,
    this.body,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
  });

  final int id;
  final int productId;
  final int userId;
  final int rating;
  final String? title;
  final String? body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userName;

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return ProductReview(
      id: json['id'] as int,
      productId: json['productId'] as int,
      userId: json['userId'] as int,
      rating: json['rating'] as int,
      title: json['title'] as String?,
      body: json['body'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      userName: user?['name'] as String?,
    );
  }
}

class ReviewsPage {
  const ReviewsPage({required this.data, required this.nextCursor});
  final List<ProductReview> data;
  final int? nextCursor;
}

/// One-shot PDP summary: average, count, how many came from verified
/// buyers, a zero-filled 1..5 histogram, and the three most recent
/// reviews so the section renders without a follow-up list call.
class ReviewSummary {
  const ReviewSummary({
    required this.ratingAvg,
    required this.ratingCount,
    required this.verifiedCount,
    required this.histogram,
    required this.recent,
  });

  final double? ratingAvg;
  final int ratingCount;
  final int verifiedCount;

  /// Star (1..5) → number of reviews at that star. Always fully keyed.
  final Map<int, int> histogram;
  final List<ProductReview> recent;

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final rawHist = json['histogram'] as Map<String, dynamic>? ?? const {};
    final hist = <int, int>{for (var s = 1; s <= 5; s++) s: 0};
    rawHist.forEach((key, value) {
      final star = int.tryParse(key);
      if (star != null && hist.containsKey(star)) {
        hist[star] = (value as num).toInt();
      }
    });
    final avg = json['ratingAvg'];
    return ReviewSummary(
      ratingAvg: avg == null ? null : (avg as num).toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      verifiedCount: (json['verifiedCount'] as num?)?.toInt() ?? 0,
      histogram: hist,
      recent: (json['recent'] as List<dynamic>? ?? const [])
          .map((e) => ProductReview.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
