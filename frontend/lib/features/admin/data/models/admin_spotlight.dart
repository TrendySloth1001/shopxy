import 'package:shopxy/features/spotlight/data/models/spotlight.dart';

/// Admin view of a brand spotlight — same shape as the merchant model
/// plus the reviewer id and the (nested) shop summary the approval
/// page renders alongside each card.
class AdminSpotlight {
  const AdminSpotlight({
    required this.id,
    required this.shopId,
    required this.shop,
    required this.dealLabel,
    this.subtitle,
    required this.heroImageUrl,
    required this.bgColor,
    this.accentColor,
    this.ctaTarget,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedByUserId,
    required this.createdAt,
  });

  final int id;
  final int shopId;
  final AdminSpotlightShop shop;
  final String dealLabel;
  final String? subtitle;
  final String heroImageUrl;
  final String bgColor;
  final String? accentColor;
  final String? ctaTarget;
  final DateTime startAt;
  final DateTime endAt;
  final SpotlightStatus status;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final int? reviewedByUserId;
  final DateTime createdAt;

  factory AdminSpotlight.fromJson(Map<String, dynamic> j) => AdminSpotlight(
        id: j['id'] as int,
        shopId: j['shopId'] as int,
        shop: AdminSpotlightShop.fromJson(j['shop'] as Map<String, dynamic>),
        dealLabel: j['dealLabel'] as String,
        subtitle: j['subtitle'] as String?,
        heroImageUrl: j['heroImageUrl'] as String,
        bgColor: j['bgColor'] as String,
        accentColor: j['accentColor'] as String?,
        ctaTarget: j['ctaTarget'] as String?,
        startAt: DateTime.parse(j['startAt'] as String),
        endAt: DateTime.parse(j['endAt'] as String),
        status: spotlightStatusFromWire(j['status'] as String),
        rejectionReason: j['rejectionReason'] as String?,
        reviewedAt: (j['reviewedAt'] as String?) != null
            ? DateTime.tryParse(j['reviewedAt'] as String)
            : null,
        reviewedByUserId: j['reviewedByUserId'] as int?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class AdminSpotlightShop {
  const AdminSpotlightShop({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
  });
  final int id;
  final String name;
  final String slug;
  final String? logoUrl;

  factory AdminSpotlightShop.fromJson(Map<String, dynamic> j) =>
      AdminSpotlightShop(
        id: j['id'] as int,
        name: j['name'] as String,
        slug: j['slug'] as String,
        logoUrl: j['logoUrl'] as String?,
      );
}

class AdminSpotlightsPage {
  const AdminSpotlightsPage({required this.data, required this.nextCursor});
  final List<AdminSpotlight> data;
  final int? nextCursor;
}
