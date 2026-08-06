/// How refunds are issued when a return is approved.
const kRefundModes = ['WALLET', 'ORIGINAL', 'REPLACEMENT'];

/// Latest order stage at which a customer may still cancel; after that
/// they must use a post-delivery return.
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
  /// Whether customers may request post-delivery returns at all.
  final bool returnsEnabled;
  /// Days after delivery a return can be requested. 0 = no limit.
  final int returnWindowDays;
  /// One of [kRefundModes].
  final String refundMode;
  /// Optional customer-visible note shown with the return policy.
  final String? returnPolicyNote;
  /// One of [kCancellationPolicies] — the latest order stage at which
  /// a customer may still cancel.
  final String cancellationPolicy;
  /// Day → [open, close] in HH:MM. Missing days = closed. Null when
  /// the merchant hasn't set any hours.
  final Map<String, List<String>>? operatingHours;
  /// Which of the ~7 preset PDF looks this shop's invoices/quotations/
  /// challans render with — see `PdfTemplate` in the `pdf_templates` feature.
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

  /// Tolerant enum parse — unknown server values fall back so a newer
  /// backend can't crash an older app build.
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
