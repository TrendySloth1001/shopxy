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
    this.isVerified = false,
    this.locationCity,
    this.locationState,
    this.returnPolicy,
    this.shippingPolicy,
    this.refundPolicy,
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
  final bool isPublished;
  final double? rating;
  final int ratingCount;
  /// Platform-admin verified flag — drives the "Verified" badge.
  final bool isVerified;
  final String? locationCity;
  final String? locationState;
  final String? returnPolicy;
  final String? shippingPolicy;
  final String? refundPolicy;
  /// When true, the shop blocks new orders and shows a "Vacation"
  /// banner on every PDP. Existing orders continue normally.
  final bool vacationMode;
  /// Customer-visible message rendered alongside the vacation banner.
  final String? vacationMessage;
  /// Day → [open, close] in HH:MM. Missing days = closed. Null when
  /// the merchant hasn't set any hours.
  final Map<String, List<String>>? operatingHours;

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
        isVerified: (json['isVerified'] as bool?) ?? false,
        locationCity: json['locationCity'] as String?,
        locationState: json['locationState'] as String?,
        returnPolicy: json['returnPolicy'] as String?,
        shippingPolicy: json['shippingPolicy'] as String?,
        refundPolicy: json['refundPolicy'] as String?,
        vacationMode: (json['vacationMode'] as bool?) ?? false,
        vacationMessage: json['vacationMessage'] as String?,
        operatingHours: _parseHours(json['operatingHours']),
      );

  static Map<String, List<String>>? _parseHours(dynamic raw) {
    if (raw is! Map) return null;
    final out = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is List && value.length == 2) {
        out[key] = [value[0].toString(), value[1].toString()];
      }
    }
    return out.isEmpty ? null : out;
  }
}
