import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';

/// Mirror of the backend `BannerSlideMode` enum. TEMPLATED slides use
/// the 7-card `BannerTemplate` renderers; FREEFORM slides use the
/// positioned `textBlocks` + `imageTransform` payload and ignore
/// `template`.
enum CarouselSlideMode { templated, freeform }

extension CarouselSlideModeX on CarouselSlideMode {
  String get wire {
    switch (this) {
      case CarouselSlideMode.templated:
        return 'TEMPLATED';
      case CarouselSlideMode.freeform:
        return 'FREEFORM';
    }
  }

  String get label {
    switch (this) {
      case CarouselSlideMode.templated:
        return 'Templated';
      case CarouselSlideMode.freeform:
        return 'Freeform';
    }
  }
}

CarouselSlideMode carouselSlideModeFromWire(String? s) {
  switch (s) {
    case 'FREEFORM':
      return CarouselSlideMode.freeform;
    case 'TEMPLATED':
    default:
      return CarouselSlideMode.templated;
  }
}

/// Carousel — the named campaign-style parent of slides. A merchant
/// can own multiple carousels (e.g. "Spring sale", "New drops"), each
/// targeting one of the four `BannerPlacement` values. Carousel-level
/// `isActive` + schedule cascade to every slide inside.
@immutable
class Carousel {
  const Carousel({
    required this.id,
    required this.name,
    required this.placement,
    required this.isActive,
    required this.sortOrder,
    required this.slideCount,
    this.shopId,
    this.startAt,
    this.endAt,
  });

  final int id;
  /// Null = platform-curated carousel (admin-managed). Merchant
  /// surfaces only ever see their own shopId; admin can list both.
  final int? shopId;
  final String name;
  final BannerPlacement placement;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final int sortOrder;
  final int slideCount;

  factory Carousel.fromJson(Map<String, dynamic> j) => Carousel(
        id: j['id'] as int,
        shopId: j['shopId'] as int?,
        name: j['name'] as String,
        placement: bannerPlacementFromWire(j['placement'] as String),
        isActive: (j['isActive'] as bool?) ?? true,
        startAt: (j['startAt'] as String?) != null
            ? DateTime.tryParse(j['startAt'] as String)
            : null,
        endAt: (j['endAt'] as String?) != null
            ? DateTime.tryParse(j['endAt'] as String)
            : null,
        sortOrder: (j['sortOrder'] as int?) ?? 0,
        // The listForShop endpoint returns `_count: { slides: int }`.
        // Individual carousel reads (GET /:id) don't include it; default
        // to 0 there — the page that needs the count loads slides itself.
        slideCount: ((j['_count'] as Map?)?['slides'] as int?) ?? 0,
      );
}

/// One text block on a FREEFORM slide. Positioning is percent-of-
/// canvas; the renderer resolves these against the actual rendered
/// card size so the same payload renders consistently across screen
/// densities.
@immutable
class CarouselSlideTextBlock {
  const CarouselSlideTextBlock({
    required this.id,
    required this.text,
    required this.xPct,
    required this.yPct,
    required this.widthPct,
    required this.fontSize,
    required this.color,
    required this.weight,
    required this.align,
  });

  final String id;
  final String text;
  final double xPct;
  final double yPct;
  final double widthPct;
  final int fontSize;
  /// `#RRGGBB` or `#RRGGBBAA` — same shape as the editor's hex fields.
  final String color;
  /// FontWeight integer (400/500/600/700/800/900).
  final int weight;
  /// 'left' | 'center' | 'right'.
  final String align;

  factory CarouselSlideTextBlock.fromJson(Map<String, dynamic> j) =>
      CarouselSlideTextBlock(
        id: j['id'] as String,
        text: j['text'] as String,
        xPct: (j['xPct'] as num).toDouble(),
        yPct: (j['yPct'] as num).toDouble(),
        widthPct: (j['widthPct'] as num).toDouble(),
        fontSize: (j['fontSize'] as num).toInt(),
        color: j['color'] as String,
        weight: (j['weight'] as num).toInt(),
        align: j['align'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'xPct': xPct,
        'yPct': yPct,
        'widthPct': widthPct,
        'fontSize': fontSize,
        'color': color,
        'weight': weight,
        'align': align,
      };
}

/// FREEFORM-mode image transform. Mirrors the backend zod shape; all
/// numeric axes match the server-side bounds (focal [0,100], scale
/// [0.25,4], rotateDeg [-180,180], filter axes [0.5,1.5]).
@immutable
class CarouselSlideImageTransform {
  const CarouselSlideImageTransform({
    this.focalXPct = 50,
    this.focalYPct = 50,
    this.scale = 1,
    this.rotateDeg = 0,
    this.flipH = false,
    this.flipV = false,
    this.brightness = 1,
    this.contrast = 1,
    this.saturation = 1,
  });

  final double focalXPct;
  final double focalYPct;
  final double scale;
  final double rotateDeg;
  final bool flipH;
  final bool flipV;
  final double brightness;
  final double contrast;
  final double saturation;

  static const identity = CarouselSlideImageTransform();

  factory CarouselSlideImageTransform.fromJson(Map<String, dynamic> j) =>
      CarouselSlideImageTransform(
        focalXPct: (j['focalXPct'] as num?)?.toDouble() ?? 50,
        focalYPct: (j['focalYPct'] as num?)?.toDouble() ?? 50,
        scale: (j['scale'] as num?)?.toDouble() ?? 1,
        rotateDeg: (j['rotateDeg'] as num?)?.toDouble() ?? 0,
        flipH: (j['flipH'] as bool?) ?? false,
        flipV: (j['flipV'] as bool?) ?? false,
        brightness: (j['brightness'] as num?)?.toDouble() ?? 1,
        contrast: (j['contrast'] as num?)?.toDouble() ?? 1,
        saturation: (j['saturation'] as num?)?.toDouble() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'focalXPct': focalXPct,
        'focalYPct': focalYPct,
        'scale': scale,
        'rotateDeg': rotateDeg,
        'flipH': flipH,
        'flipV': flipV,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
      };

  CarouselSlideImageTransform copyWith({
    double? focalXPct,
    double? focalYPct,
    double? scale,
    double? rotateDeg,
    bool? flipH,
    bool? flipV,
    double? brightness,
    double? contrast,
    double? saturation,
  }) {
    return CarouselSlideImageTransform(
      focalXPct: focalXPct ?? this.focalXPct,
      focalYPct: focalYPct ?? this.focalYPct,
      scale: scale ?? this.scale,
      rotateDeg: rotateDeg ?? this.rotateDeg,
      flipH: flipH ?? this.flipH,
      flipV: flipV ?? this.flipV,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
    );
  }
}

/// One slide inside a carousel. Backed by the same `banners` table as
/// `AdminBanner` — the new fields (`mode`, `textBlocks`,
/// `imageTransform`, `carouselId`) extend the existing payload rather
/// than introducing a separate type, since the editor and customer
/// renderer both branch on `mode` and use either the templated columns
/// or the freeform payload.
@immutable
class CarouselSlide {
  const CarouselSlide({
    required this.id,
    required this.carouselId,
    required this.placement,
    required this.mode,
    required this.template,
    required this.imageFit,
    required this.title,
    required this.imageUrl,
    required this.bgColor,
    required this.sortOrder,
    required this.isActive,
    this.subtitle,
    this.eyebrow,
    this.ctaText,
    this.ctaTarget,
    this.brandLabel,
    this.accentColor,
    this.textBlocks = const [],
    this.imageTransform,
    this.startAt,
    this.endAt,
  });

  final int id;
  final int? carouselId;
  final BannerPlacement placement;
  final CarouselSlideMode mode;
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
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<CarouselSlideTextBlock> textBlocks;
  final CarouselSlideImageTransform? imageTransform;

  factory CarouselSlide.fromJson(Map<String, dynamic> j) {
    final blocksRaw = j['textBlocks'];
    final blocks = blocksRaw is List
        ? blocksRaw
            .map((e) => CarouselSlideTextBlock.fromJson(
                  e as Map<String, dynamic>,
                ))
            .toList()
        : const <CarouselSlideTextBlock>[];
    final tx = j['imageTransform'];
    return CarouselSlide(
      id: j['id'] as int,
      carouselId: j['carouselId'] as int?,
      placement: bannerPlacementFromWire(j['placement'] as String),
      mode: carouselSlideModeFromWire(j['mode'] as String?),
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
      isActive: (j['isActive'] as bool?) ?? true,
      startAt: (j['startAt'] as String?) != null
          ? DateTime.tryParse(j['startAt'] as String)
          : null,
      endAt: (j['endAt'] as String?) != null
          ? DateTime.tryParse(j['endAt'] as String)
          : null,
      textBlocks: blocks,
      imageTransform: tx is Map<String, dynamic>
          ? CarouselSlideImageTransform.fromJson(tx)
          : null,
    );
  }
}
