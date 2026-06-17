import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Aggregate that the home page consumes. Built from the raw `/home/feed`
/// + `/me/home/personalized` JSON payloads by the mapping helpers below.
class HomeFeed {
  const HomeFeed({
    required this.heroSlides,
    required this.categoryPucks,
    required this.adStrip,
    required this.promoBanners,
    required this.curatedRails,
    required this.trending,
    required this.newInStock,
    required this.recommended,
    required this.recentlyViewed,
  });

  final List<HeroSlide> heroSlides;
  final List<CategoryPuck> categoryPucks;
  // adStrip / promoBanners / curatedRails are all banner placements —
  // each is just a plain tappable image + optional link, distinguished
  // only by where on the page they render.
  final List<HeroSlide> adStrip;
  final List<HeroSlide> promoBanners;
  final List<HeroSlide> curatedRails;
  final List<ProductCard> trending;
  final List<ProductCard> newInStock;
  final List<ProductCard> recommended;
  final List<ProductCard> recentlyViewed;

  static const HomeFeed empty = HomeFeed(
    heroSlides: [],
    categoryPucks: [],
    adStrip: [],
    promoBanners: [],
    curatedRails: [],
    trending: [],
    newInStock: [],
    recommended: [],
    recentlyViewed: [],
  );

  HomeFeed copyWith({
    List<ProductCard>? recommended,
    List<ProductCard>? recentlyViewed,
  }) {
    return HomeFeed(
      heroSlides: heroSlides,
      categoryPucks: categoryPucks,
      adStrip: adStrip,
      promoBanners: promoBanners,
      curatedRails: curatedRails,
      trending: trending,
      newInStock: newInStock,
      recommended: recommended ?? this.recommended,
      recentlyViewed: recentlyViewed ?? this.recentlyViewed,
    );
  }
}

/// Pure mappers from backend JSON → presentation models.
///
/// They live separate from the data source so widget tests can construct
/// fake JSON and drive the same code path the real network would.
class HomeFeedMapper {
  HomeFeedMapper._();

  static HomeFeed fromFeed(Map<String, dynamic> json) {
    final heroBanners = _list(json['heroBanners']);
    final adStrip = _list(json['adStripBanners']);
    final promoBanners = _list(json['promoBanners']);
    final curatedRailBanners = _list(json['curatedRailBanners']);
    final trending = _list(json['trending']);
    // Server sends raw Product rows under `newArrivals`, so we feed them
    // through the same mapper the endless page uses.
    final newArrivals = _list(json['newArrivals']);
    final pucks = _list(json['categoryPucks']);

    return HomeFeed(
      heroSlides: heroBanners.map(_heroFromBanner).toList(),
      adStrip: adStrip.map(_heroFromBanner).toList(),
      promoBanners: promoBanners.map(_heroFromBanner).toList(),
      curatedRails: curatedRailBanners.map(_heroFromBanner).toList(),
      categoryPucks: pucks.asMap().entries.map(_categoryPuck).toList(),
      trending: trending
          .map(_productCardFromTrending)
          .whereType<ProductCard>()
          .toList(),
      newInStock: fromEndlessPage(newArrivals),
      recommended: const [],
      recentlyViewed: const [],
    );
  }

  /// Endless-scroll page → list of ProductCard. The endpoint returns
  /// raw Product rows (not the trending-wrap shape) so we route directly
  /// through `_productCardFromProduct`.
  static List<ProductCard> fromEndlessPage(List<dynamic> rows) {
    return rows
        .map((r) => r is Map<String, dynamic> ? _productCardFromProduct(r) : null)
        .whereType<ProductCard>()
        .toList();
  }

  static ({List<ProductCard> recommended, List<ProductCard> recentlyViewed}) fromPersonalized(
    Map<String, dynamic> json,
  ) {
    final recommended = _list(json['recommended'])
        .map((p) => _productCardFromProduct(p as Map<String, dynamic>))
        .whereType<ProductCard>()
        .toList();
    final recentlyViewed = _list(json['recentlyViewed'])
        .map((row) {
          final product = (row as Map<String, dynamic>)['product'];
          if (product is! Map<String, dynamic>) return null;
          return _productCardFromProduct(product);
        })
        .whereType<ProductCard>()
        .toList();
    return (recommended: recommended, recentlyViewed: recentlyViewed);
  }

  // ── Banner → HeroSlide ────────────────────────────────────────────

  static HeroSlide _heroFromBanner(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return HeroSlide(
      id: _asInt(m['id']) ?? 0,
      imageUrl: (m['imageUrl'] ?? '') as String,
      linkUrl: (m['linkUrl'] as String?)?.trim().isEmpty == false
          ? (m['linkUrl'] as String).trim()
          : null,
      productCount: _asInt(m['productCount']) ?? 0,
    );
  }

  // ── Trending ────────────────────────────────────────────────────

  static ProductCard? _productCardFromTrending(dynamic row) {
    final m = row as Map<String, dynamic>;
    final product = m['product'] as Map<String, dynamic>?;
    if (product == null) return null;
    return _productCardFromProduct(product);
  }

  static ProductCard? _productCardFromProduct(Map<String, dynamic> p) {
    final mrp = _asDouble(p['mrp']);
    final selling = _asDouble(p['sellingPrice']) ?? mrp ?? 0;
    if (selling <= 0) return null;
    final image = _firstImage(p);
    final ratingCount = _asInt(p['ratingCount']) ?? 0;
    final shop = p['shop'] as Map<String, dynamic>?;
    final discountPct = (mrp != null && mrp > selling)
        ? ((1 - selling / mrp) * 100).clamp(0, 99).round()
        : 0;
    return ProductCard(
      productId: _asInt(p['id']) ?? 0,
      name: (p['name'] ?? '') as String,
      price: _money(selling),
      originalPrice: mrp != null && mrp > selling ? _money(mrp) : '',
      bankPrice: _money(selling * 0.95),
      rating: _asDouble(p['ratingAvg']) ?? 0,
      ratingCount: ratingCount > 999
          ? '${(ratingCount / 1000).toStringAsFixed(1)}k'
          : '$ratingCount',
      ratingCountRaw: ratingCount,
      imageUrl: image,
      bgColor: AppColors.heroPanel,
      shopSlug: shop?['slug'] as String?,
      brand: p['brand'] as String?,
      discountPct: discountPct,
    );
  }

  // ── Category pucks ────────────────────────────────────────────────

  static CategoryPuck _categoryPuck(MapEntry<int, dynamic> e) {
    final m = e.value as Map<String, dynamic>;
    return CategoryPuck(
      categoryId: (m['id'] as num).toInt(),
      slug: (m['slug'] ?? '') as String,
      label: (m['name'] ?? '') as String,
      imageUrl: m['imageUrl'] as String?,
      tint: _puckTints[e.key % _puckTints.length],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  static List<dynamic> _list(dynamic v) =>
      v is List ? v : const <dynamic>[];

  /// Prisma `Decimal` fields serialise as **strings** in JSON (e.g.
  /// `"199.00"`), not numbers. Anywhere we read a price / rating /
  /// score from a Prisma row we must accept both. Returns null on
  /// anything we can't parse so callers fall back to a sensible default.
  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String _firstImage(Map<String, dynamic> product) {
    final imgs = product['images'];
    if (imgs is List && imgs.isNotEmpty) {
      final first = imgs.first;
      if (first is Map<String, dynamic>) return (first['url'] ?? '') as String;
    }
    return '';
  }

  // MOD-1: shared formatter — see AppFormat.
  static String _money(double v) => AppFormat.rupees(v);

  /// Soft palette for the puck strip — cycles by index so adjacent
  /// categories never share a tint.
  static const List<Color> _puckTints = [
    Color(0xFFE3E8F4),
    Color(0xFFF3E4D6),
    Color(0xFFF9E1EA),
    Color(0xFFE6F2EC),
    Color(0xFFEFE9DD),
    Color(0xFFE0E1E6),
    Color(0xFFE7DFD4),
    Color(0xFFE4DECF),
    Color(0xFFE6F2DA),
    Color(0xFFDEEAF1),
  ];
}
