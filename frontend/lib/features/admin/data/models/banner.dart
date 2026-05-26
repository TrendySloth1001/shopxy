enum BannerPlacement { hero, adStrip, promo, curatedRail }

/// Visual layout the slide renders with on the customer side. The
/// merchant picks one of these when authoring; the customer carousel
/// branches on it to render the matching template. New variants are
/// appended — the wire enum on the server stays additive too.
enum BannerTemplate {
  /// Original branded card — eyebrow chip + title + subtitle + button.
  classic,

  /// Editorial: centered title, small accent text, circular medallion.
  minimal,

  /// Full-bleed image only — merchant supplies ready-made banner art.
  imageOnly,

  /// 50/50 split. Solid colour panel one side, image on the other.
  split,

  /// Full-bleed image + dark scrim, centered white text.
  overlay,

  /// Big % OFF / deal badge in the corner, product hero on the side.
  deal,

  /// Image on top, solid colour text panel below — movie-poster style.
  poster,
}

extension BannerTemplateX on BannerTemplate {
  String get wire {
    switch (this) {
      case BannerTemplate.classic:
        return 'CLASSIC';
      case BannerTemplate.minimal:
        return 'MINIMAL';
      case BannerTemplate.imageOnly:
        return 'IMAGE_ONLY';
      case BannerTemplate.split:
        return 'SPLIT';
      case BannerTemplate.overlay:
        return 'OVERLAY';
      case BannerTemplate.deal:
        return 'DEAL';
      case BannerTemplate.poster:
        return 'POSTER';
    }
  }

  String get label {
    switch (this) {
      case BannerTemplate.classic:
        return 'Classic';
      case BannerTemplate.minimal:
        return 'Minimal';
      case BannerTemplate.imageOnly:
        return 'Image only';
      case BannerTemplate.split:
        return 'Split';
      case BannerTemplate.overlay:
        return 'Overlay';
      case BannerTemplate.deal:
        return 'Deal';
      case BannerTemplate.poster:
        return 'Poster';
    }
  }

  String get description {
    switch (this) {
      case BannerTemplate.classic:
        return 'Brand chip, headline, subtitle and a Shop now button overlaid on your photo.';
      case BannerTemplate.minimal:
        return 'Centered headline with a small accent label and a circular product medallion.';
      case BannerTemplate.imageOnly:
        return 'Just your uploaded image, edge to edge. No headline or buttons added.';
      case BannerTemplate.split:
        return 'Solid colour panel on one side with your text and button, photo on the other half.';
      case BannerTemplate.overlay:
        return 'Full-bleed image with a dark scrim. Centered white text — works on any photo.';
      case BannerTemplate.deal:
        return 'Big % OFF badge in the corner, product hero on the right. Use the brand label as the deal text.';
      case BannerTemplate.poster:
        return 'Image on top, solid colour panel below with title and accent chip. Movie-poster style.';
    }
  }

  /// Whether the body subtitle is rendered. Image-only hides it because
  /// the merchant's artwork already carries any copy.
  bool get supportsSubtitle => this != BannerTemplate.imageOnly;

  /// Whether the brand label / eyebrow / CTA fields are meaningful.
  bool get supportsTextFields => this != BannerTemplate.imageOnly;

  /// Whether the merchant should pick BG / accent colours.
  bool get supportsColors => this != BannerTemplate.imageOnly;
}

/// How the slide's image fills its slot. COVER crops to fit, CONTAIN
/// letterboxes so artwork isn't clipped.
enum BannerImageFit { cover, contain }

extension BannerImageFitX on BannerImageFit {
  String get wire {
    switch (this) {
      case BannerImageFit.cover:
        return 'COVER';
      case BannerImageFit.contain:
        return 'CONTAIN';
    }
  }

  String get label {
    switch (this) {
      case BannerImageFit.cover:
        return 'Fill';
      case BannerImageFit.contain:
        return 'Fit';
    }
  }
}

BannerImageFit bannerImageFitFromWire(String? s) {
  if (s == 'CONTAIN') return BannerImageFit.contain;
  return BannerImageFit.cover;
}

BannerTemplate bannerTemplateFromWire(String? s) {
  switch (s) {
    case 'MINIMAL':
      return BannerTemplate.minimal;
    case 'IMAGE_ONLY':
      return BannerTemplate.imageOnly;
    case 'SPLIT':
      return BannerTemplate.split;
    case 'OVERLAY':
      return BannerTemplate.overlay;
    case 'DEAL':
      return BannerTemplate.deal;
    case 'POSTER':
      return BannerTemplate.poster;
    case 'CLASSIC':
    default:
      return BannerTemplate.classic;
  }
}

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
    this.template = BannerTemplate.classic,
    this.imageFit = BannerImageFit.cover,
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
  final BannerTemplate template;
  final BannerImageFit imageFit;
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
        template: bannerTemplateFromWire(j['template'] as String?),
        imageFit: bannerImageFitFromWire(j['imageFit'] as String?),
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
