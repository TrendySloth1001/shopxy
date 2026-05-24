class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.slug,
    this.tagline,
    this.logoUrl,
    this.bannerUrl,
    required this.isPublished,
    this.rating,
    required this.ratingCount,
  });

  final int id;
  final String name;
  final String slug;
  final String? tagline;
  final String? logoUrl;
  final String? bannerUrl;
  final bool isPublished;
  final double? rating;
  final int ratingCount;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
        tagline: json['tagline'] as String?,
        logoUrl: json['logoUrl'] as String?,
        bannerUrl: json['bannerUrl'] as String?,
        isPublished: (json['isPublished'] as bool?) ?? false,
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: (json['ratingCount'] as int?) ?? 0,
      );
}
