/// Public storefront a customer can browse. Subset of the merchant
/// Shop model — never carries `isPublished` (would-be 404s never reach
/// the client) or owner identity.
class MarketplaceShop {
  const MarketplaceShop({
    required this.id,
    required this.name,
    required this.slug,
    this.tagline,
    this.logoUrl,
    this.bannerUrl,
    this.rating,
    this.ratingCount = 0,
  });

  final int id;
  final String name;
  final String slug;
  final String? tagline;
  final String? logoUrl;
  final String? bannerUrl;
  final double? rating;
  final int ratingCount;

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory MarketplaceShop.fromJson(Map<String, dynamic> j) {
    return MarketplaceShop(
      id: j['id'] as int,
      name: j['name'] as String,
      slug: j['slug'] as String,
      tagline: j['tagline'] as String?,
      logoUrl: j['logoUrl'] as String?,
      bannerUrl: j['bannerUrl'] as String?,
      rating: _asDouble(j['rating']),
      ratingCount: j['ratingCount'] as int? ?? 0,
    );
  }
}
