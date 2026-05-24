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
