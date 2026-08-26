class LinkedMerchant {
  const LinkedMerchant({
    required this.shopId,
    required this.ownerUserId,
    required this.name,
    required this.slug,
    required this.isPublished,
    required this.linkedAsParty,
    required this.linkedAsVendor,
    this.tagline,
    this.logoUrl,
    this.bannerUrl,
    this.rating,
    this.ratingCount = 0,
  });

  final String shopId;

  final String ownerUserId;

  final String name;

  final String slug;

  final bool isPublished;

  final bool linkedAsParty;

  final bool linkedAsVendor;

  final String? tagline;
  final String? logoUrl;
  final String? bannerUrl;
  final double? rating;
  final int ratingCount;

  factory LinkedMerchant.fromJson(Map<String, dynamic> j) {
    final roles = j['roles'] as Map<String, dynamic>? ?? const {};
    return LinkedMerchant(
      shopId: j['id'].toString(),
      ownerUserId: j['ownerUserId'].toString(),
      name: j['name'] as String,
      slug: j['slug'] as String,
      isPublished: j['isPublished'] as bool? ?? false,
      linkedAsParty: roles['party'] as bool? ?? false,
      linkedAsVendor: roles['vendor'] as bool? ?? false,
      tagline: j['tagline'] as String?,
      logoUrl: j['logoUrl'] as String?,
      bannerUrl: j['bannerUrl'] as String?,
      rating: _d(j['rating']),
      ratingCount: j['ratingCount'] as int? ?? 0,
    );
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
