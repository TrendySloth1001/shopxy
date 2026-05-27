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
    this.vacationMode = false,
    this.vacationMessage,
    this.operatingHours,
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
  /// When true, the shop is on vacation — the customer PDP shows a
  /// banner and add-to-cart is muted with a snackbar.
  final bool vacationMode;
  final String? vacationMessage;
  /// `mon` → ['09:00', '21:00']. Days not in the map = closed.
  final Map<String, List<String>>? operatingHours;

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
      vacationMode: (j['vacationMode'] as bool?) ?? false,
      vacationMessage: j['vacationMessage'] as String?,
      operatingHours: _parseHours(j['operatingHours']),
    );
  }

  static Map<String, List<String>>? _parseHours(dynamic raw) {
    if (raw is! Map) return null;
    final out = <String, List<String>>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (v is List && v.length == 2) {
        out[e.key.toString()] = [v[0].toString(), v[1].toString()];
      }
    }
    return out.isEmpty ? null : out;
  }
}
