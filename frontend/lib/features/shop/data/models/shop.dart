const kRefundModes = ['WALLET', 'ORIGINAL', 'REPLACEMENT'];

const kCancellationPolicies = [
  'UNTIL_CONFIRMED',
  'UNTIL_PACKED',
  'UNTIL_SHIPPED',
  'UNTIL_DELIVERED',
];

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
    this.returnsEnabled = false,
    this.returnWindowDays = 0,
    this.refundMode = 'ORIGINAL',
    this.returnPolicyNote,
    this.cancellationPolicy = 'UNTIL_SHIPPED',
    this.operatingHours,
    this.pdfTemplateId = 'classic',
  });

  final String id;
  final String name;
  final String slug;
  final String? tagline;
  final String? logoUrl;
  final String? bannerUrl;
  final bool isPublished;
  final double? rating;
  final int ratingCount;
  final bool isVerified;
  final String? locationCity;
  final String? locationState;
  final String? returnPolicy;
  final String? shippingPolicy;
  final String? refundPolicy;
  final bool vacationMode;
  final String? vacationMessage;
  final bool returnsEnabled;
  final int returnWindowDays;
  final String refundMode;
  final String? returnPolicyNote;
  final String cancellationPolicy;
  final Map<String, List<String>>? operatingHours;
  final String pdfTemplateId;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'].toString(),
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
        returnsEnabled: (json['returnsEnabled'] as bool?) ?? false,
        returnWindowDays: (json['returnWindowDays'] as num?)?.toInt() ?? 0,
        refundMode: _enumOr(json['refundMode'], kRefundModes, 'ORIGINAL'),
        returnPolicyNote: json['returnPolicyNote'] as String?,
        cancellationPolicy: _enumOr(
          json['cancellationPolicy'],
          kCancellationPolicies,
          'UNTIL_SHIPPED',
        ),
        operatingHours: _parseHours(json['operatingHours']),
        pdfTemplateId: (json['pdfTemplateId'] as String?) ?? 'classic',
      );

  static String _enumOr(dynamic raw, List<String> allowed, String fallback) =>
      raw is String && allowed.contains(raw) ? raw : fallback;

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
