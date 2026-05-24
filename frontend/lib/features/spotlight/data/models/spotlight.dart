enum SpotlightStatus { pending, approved, rejected }

extension SpotlightStatusX on SpotlightStatus {
  String get wire {
    switch (this) {
      case SpotlightStatus.pending:
        return 'PENDING';
      case SpotlightStatus.approved:
        return 'APPROVED';
      case SpotlightStatus.rejected:
        return 'REJECTED';
    }
  }

  String get label {
    switch (this) {
      case SpotlightStatus.pending:
        return 'Pending review';
      case SpotlightStatus.approved:
        return 'Approved';
      case SpotlightStatus.rejected:
        return 'Rejected';
    }
  }
}

SpotlightStatus spotlightStatusFromWire(String s) {
  switch (s) {
    case 'APPROVED':
      return SpotlightStatus.approved;
    case 'REJECTED':
      return SpotlightStatus.rejected;
    case 'PENDING':
    default:
      return SpotlightStatus.pending;
  }
}

/// Merchant-facing view of a single spotlight request. Mirrors the
/// backend's `merchantSelect` shape; admin-only fields like the
/// reviewer user id are intentionally absent here.
class Spotlight {
  const Spotlight({
    required this.id,
    required this.shopId,
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
    required this.createdAt,
  });

  final int id;
  final int shopId;
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
  final DateTime createdAt;

  factory Spotlight.fromJson(Map<String, dynamic> j) => Spotlight(
        id: j['id'] as int,
        shopId: j['shopId'] as int,
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
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
