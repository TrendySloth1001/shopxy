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

  final String id;
  final String name;
  final String slug;
  final String? tagline;
  final String? logoUrl;
  final String? bannerUrl;
  final double? rating;
  final int ratingCount;
  final bool isVerified;
  final String? locationCity;
  final String? locationState;
  final String? returnPolicy;
  final String? shippingPolicy;
  final String? refundPolicy;
  final DateTime? joinedAt;
  final bool vacationMode;
  final String? vacationMessage;
  final Map<String, List<String>>? operatingHours;

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
      id: j['id'].toString(),
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
