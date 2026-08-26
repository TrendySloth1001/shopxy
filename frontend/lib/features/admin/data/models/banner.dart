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
    required this.imageUrl,
    this.linkUrl,
    required this.sortOrder,
    this.startAt,
    this.endAt,
    required this.isActive,
    this.productCount = 0,
  });

  final String id;
  final BannerPlacement placement;
  final String imageUrl;
  final String? linkUrl;
  final int sortOrder;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;

  final int productCount;

  factory AdminBanner.fromJson(Map<String, dynamic> j) => AdminBanner(
        id: j['id'].toString(),
        placement: bannerPlacementFromWire(j['placement'] as String),
        imageUrl: j['imageUrl'] as String,
        linkUrl: j['linkUrl'] as String?,
        sortOrder: (j['sortOrder'] as int?) ?? 0,
        startAt: (j['startAt'] as String?) != null
            ? DateTime.tryParse(j['startAt'] as String)
            : null,
        endAt: (j['endAt'] as String?) != null
            ? DateTime.tryParse(j['endAt'] as String)
            : null,
        isActive: (j['isActive'] as bool?) ?? true,
        productCount: (j['productCount'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'placement': placement.wire,
        'imageUrl': imageUrl,
        if (linkUrl != null) 'linkUrl': linkUrl,
        'sortOrder': sortOrder,
        if (startAt != null) 'startAt': startAt!.toUtc().toIso8601String(),
        if (endAt != null) 'endAt': endAt!.toUtc().toIso8601String(),
        'isActive': isActive,
      };
}

class AdminBannersPage {
  const AdminBannersPage({required this.data, required this.nextCursor});
  final List<AdminBanner> data;
  final int? nextCursor;
}
