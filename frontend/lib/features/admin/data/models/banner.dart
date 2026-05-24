enum BannerPlacement { hero, adStrip, promo, curatedRail }

extension BannerPlacementX on BannerPlacement {
  String get wire {
    switch (this) {
      case BannerPlacement.hero:
        return 'HERO';
      case BannerPlacement.adStrip:
        return 'AD_STRIP';
      case BannerPlacement.promo:
        return 'PROMO';
      case BannerPlacement.curatedRail:
        return 'CURATED_RAIL';
    }
  }

  String get label {
    switch (this) {
      case BannerPlacement.hero:
        return 'Hero carousel';
      case BannerPlacement.adStrip:
        return 'Ad strip';
      case BannerPlacement.promo:
        return 'Promo banner';
      case BannerPlacement.curatedRail:
        return 'Curated rail';
    }
  }
}

BannerPlacement bannerPlacementFromWire(String s) {
  switch (s) {
    case 'HERO':
      return BannerPlacement.hero;
    case 'AD_STRIP':
      return BannerPlacement.adStrip;
    case 'PROMO':
      return BannerPlacement.promo;
    case 'CURATED_RAIL':
      return BannerPlacement.curatedRail;
    default:
      return BannerPlacement.hero;
  }
}

class AdminBanner {
  const AdminBanner({
    required this.id,
    required this.placement,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.ctaText,
    this.ctaTarget,
    this.brandLabel,
    required this.imageUrl,
    required this.bgColor,
    this.accentColor,
    required this.sortOrder,
    this.startAt,
    this.endAt,
    required this.isActive,
    this.sponsorShopId,
  });

  final int id;
  final BannerPlacement placement;
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? ctaText;
  final String? ctaTarget;
  final String? brandLabel;
  final String imageUrl;
  final String bgColor;
  final String? accentColor;
  final int sortOrder;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final int? sponsorShopId;

  factory AdminBanner.fromJson(Map<String, dynamic> j) => AdminBanner(
        id: j['id'] as int,
        placement: bannerPlacementFromWire(j['placement'] as String),
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        eyebrow: j['eyebrow'] as String?,
        ctaText: j['ctaText'] as String?,
        ctaTarget: j['ctaTarget'] as String?,
        brandLabel: j['brandLabel'] as String?,
        imageUrl: j['imageUrl'] as String,
        bgColor: j['bgColor'] as String,
        accentColor: j['accentColor'] as String?,
        sortOrder: (j['sortOrder'] as int?) ?? 0,
        startAt: (j['startAt'] as String?) != null
            ? DateTime.tryParse(j['startAt'] as String)
            : null,
        endAt: (j['endAt'] as String?) != null
            ? DateTime.tryParse(j['endAt'] as String)
            : null,
        isActive: (j['isActive'] as bool?) ?? true,
        sponsorShopId: j['sponsorShopId'] as int?,
      );
}

class AdminBannersPage {
  const AdminBannersPage({required this.data, required this.nextCursor});
  final List<AdminBanner> data;
  final int? nextCursor;
}
