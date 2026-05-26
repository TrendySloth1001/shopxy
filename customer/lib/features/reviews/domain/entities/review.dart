/// One product review as the customer app consumes it. Mirrors the
/// `reviewSelect` shape on the backend so any field added there only
/// needs a single setter wired in fromJson.
class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.title,
    required this.body,
    required this.authorName,
    required this.authorId,
    required this.createdAt,
  });

  final int id;
  final int rating;
  final String? title;
  final String? body;
  final String authorName;
  final int authorId;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>?;
    return Review(
      id: (j['id'] as num).toInt(),
      rating: (j['rating'] as num).toInt(),
      title: j['title'] as String?,
      body: j['body'] as String?,
      authorName: (user?['name'] ?? 'Anonymous') as String,
      authorId: (user?['id'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '') as String) ?? DateTime.now(),
    );
  }
}

/// One-shot summary payload from /products/:id/reviews/summary —
/// drives the PDP block without a follow-up list call.
class ReviewSummary {
  const ReviewSummary({
    required this.ratingAvg,
    required this.ratingCount,
    required this.histogram,
    required this.recent,
  });

  /// May be null if the product has no reviews yet — the section
  /// switches to its "Be the first to review" empty state.
  final double? ratingAvg;
  final int ratingCount;
  /// 5 -> count, 4 -> count, ..., 1 -> count. Always present (zero-filled).
  final Map<int, int> histogram;
  final List<Review> recent;

  factory ReviewSummary.fromJson(Map<String, dynamic> j) {
    final hist = (j['histogram'] as Map?) ?? const {};
    final parsed = <int, int>{
      for (int i = 1; i <= 5; i++)
        i: ((hist[i.toString()] ?? hist[i]) as num?)?.toInt() ?? 0,
    };
    final avg = j['ratingAvg'];
    return ReviewSummary(
      ratingAvg: avg is num
          ? avg.toDouble()
          : avg is String
              ? double.tryParse(avg)
              : null,
      ratingCount: (j['ratingCount'] as num?)?.toInt() ?? 0,
      histogram: parsed,
      recent: ((j['recent'] as List?) ?? const [])
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReviewsPage {
  const ReviewsPage({required this.data, required this.nextCursor});
  final List<Review> data;
  final int? nextCursor;
}
