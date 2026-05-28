import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';

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

/// One slide inside a carousel. Backed by the `banners` table — the
/// editor + customer renderer use this directly via the seven
/// `BannerTemplate` layouts.
@immutable
class CarouselSlide {
  const CarouselSlide({
    required this.id,
    required this.carouselId,
    required this.placement,
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
    this.brandImageUrl,
    this.brandImageFit = BannerImageFit.cover,
    this.accentColor,
    this.startAt,
    this.endAt,
  });

  final int id;
  final int? carouselId;
  final BannerPlacement placement;
  final BannerTemplate template;
  final BannerImageFit imageFit;
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? ctaText;
  final String? ctaTarget;
  final String? brandLabel;
  /// Optional shop logo. When set, templates that render a brand chip
  /// swap the text for this image.
  final String? brandImageUrl;
  final BannerImageFit brandImageFit;
  final String imageUrl;
  final String bgColor;
  final String? accentColor;
  final int sortOrder;
  final bool isActive;
  final DateTime? startAt;
  final DateTime? endAt;

  factory CarouselSlide.fromJson(Map<String, dynamic> j) => CarouselSlide(
        id: j['id'] as int,
        carouselId: j['carouselId'] as int?,
        placement: bannerPlacementFromWire(j['placement'] as String),
        template: bannerTemplateFromWire(j['template'] as String?),
        imageFit: bannerImageFitFromWire(j['imageFit'] as String?),
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        eyebrow: j['eyebrow'] as String?,
        ctaText: j['ctaText'] as String?,
        ctaTarget: j['ctaTarget'] as String?,
        brandLabel: j['brandLabel'] as String?,
        brandImageUrl: j['brandImageUrl'] as String?,
        brandImageFit: bannerImageFitFromWire(j['brandImageFit'] as String?),
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
      );
}
