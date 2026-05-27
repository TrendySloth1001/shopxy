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
    this.isVerified = false,
    this.locationCity,
    this.locationState,
    this.returnPolicy,
    this.shippingPolicy,
    this.refundPolicy,
    this.joinedAt,
  });

  final int id;
  final String name;
  final String slug;
  final String? tagline;
  final String? logoUrl;
  final String? bannerUrl;
  final double? rating;
  final int ratingCount;
  /// Platform-admin curated trust badge.
  final bool isVerified;
  /// Where the shop physically operates from. Drives the "Based in …"
  /// trust line. Either field may be null independently.
  final String? locationCity;
  final String? locationState;
  /// Free-text policy bodies (sanitised on render). Empty → hide tab.
  final String? returnPolicy;
  final String? shippingPolicy;
  final String? refundPolicy;
  /// When the shop was first created — surfaced as "Selling since …"
  /// on the public shop page. Backend exposes this as `createdAt`.
  final DateTime? joinedAt;

  /// Composed "City, State" or just whichever half is present.
  String? get locationLabel {
    final parts = <String>[
      if ((locationCity ?? '').isNotEmpty) locationCity!.trim(),
      if ((locationState ?? '').isNotEmpty) locationState!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

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
      isVerified: (j['isVerified'] as bool?) ?? false,
      locationCity: j['locationCity'] as String?,
      locationState: j['locationState'] as String?,
      returnPolicy: j['returnPolicy'] as String?,
      shippingPolicy: j['shippingPolicy'] as String?,
      refundPolicy: j['refundPolicy'] as String?,
      joinedAt: j['createdAt'] == null
          ? null
          : DateTime.tryParse(j['createdAt'] as String),
    );
  }
}
