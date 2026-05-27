import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Aggregate that the home page consumes. Built from the raw `/home/feed`
/// + `/me/home/personalized` JSON payloads by the mapping helpers below.
class HomeFeed {
  const HomeFeed({
    required this.heroSlides,
    required this.categoryPucks,
    required this.flashDeals,
    required this.adStrip,
    required this.brandSpotlights,
    required this.promoBanners,
    required this.curatedRails,
    required this.collectionTiles,
    required this.trending,
    required this.offers,
    required this.bestValue,
    required this.newInStock,
    required this.sponsoredProducts,
    required this.recommended,
    required this.recentlyViewed,
  });

  final List<HeroSlide> heroSlides;
  final List<CategoryPuck> categoryPucks;
  final List<FlashDealProduct> flashDeals;
  final List<AdCard> adStrip;
  final List<BrandSpotlight> brandSpotlights;
  final List<AdCard> promoBanners;
  final List<CuratedRailItem> curatedRails;
  final List<CollectionTile> collectionTiles;
  final List<ProductCard> trending;
  /// Editorial subsets derived server-side from the same trending pool
  /// the rail uses. Each is short (max ~12) so the customer can render
  /// it as a horizontal carousel without scroll fatigue.
  final List<ProductCard> offers;
  final List<ProductCard> bestValue;
  final List<ProductCard> newInStock;
  /// Merchant-paid sponsored rail. Every entry has `isAd = true` and a
  /// `promotionId` set so the impression tracker can bill the right
  /// promo. Rendered as its own section with an explicit "Sponsored"
  /// label so users aren't confused with organic trending.
  final List<ProductCard> sponsoredProducts;
  final List<ProductCard> recommended;
  final List<ProductCard> recentlyViewed;

  static const HomeFeed empty = HomeFeed(
    heroSlides: [],
    categoryPucks: [],
    flashDeals: [],
    adStrip: [],
    brandSpotlights: [],
    promoBanners: [],
    curatedRails: [],
    collectionTiles: [],
    trending: [],
    offers: [],
    bestValue: [],
    newInStock: [],
    sponsoredProducts: [],
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
      flashDeals: flashDeals,
      adStrip: adStrip,
      brandSpotlights: brandSpotlights,
      promoBanners: promoBanners,
      curatedRails: curatedRails,
      collectionTiles: collectionTiles,
      trending: trending,
      offers: offers,
      bestValue: bestValue,
      newInStock: newInStock,
      sponsoredProducts: sponsoredProducts,
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
    final flashDeals = _list(json['flashDeals']);
    final spotlights = _list(json['brandSpotlights']);
    final collections = _list(json['collections']);
    final trending = _list(json['trending']);
    final offers = _list(json['offers']);
    final bestValue = _list(json['bestValue']);
    final newInStock = _list(json['newInStock']);
    final sponsored = _list(json['sponsoredProducts']);
    final pucks = _list(json['categoryPucks']);

    List<ProductCard> mapTrendingList(List<dynamic> rows) => rows
        .map(_productCardFromTrending)
        .whereType<ProductCard>()
        .toList();

    return HomeFeed(
      heroSlides: heroBanners.map(_heroFromBanner).toList(),
      adStrip: adStrip.map(_adCardFromBanner).toList(),
      promoBanners: promoBanners.map(_adCardFromBanner).toList(),
      curatedRails: _curatedRails(curatedRailBanners, collections),
      brandSpotlights: spotlights.map(_brandFromSpotlight).toList(),
      flashDeals: flashDeals.map(_flashFromSale).whereType<FlashDealProduct>().toList(),
      collectionTiles: collections.map(_collectionTile).toList(),
      categoryPucks: pucks.asMap().entries.map(_categoryPuck).toList(),
      trending: mapTrendingList(trending),
      offers: mapTrendingList(offers),
      bestValue: mapTrendingList(bestValue),
      newInStock: mapTrendingList(newInStock),
      sponsoredProducts: mapTrendingList(sponsored),
      recommended: const [],
      recentlyViewed: const [],
    );
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
    final blocksRaw = m['textBlocks'];
    final blocks = blocksRaw is List
        ? blocksRaw
            .whereType<Map<String, dynamic>>()
            .map(HeroSlideTextBlock.fromJson)
            .toList()
        : const <HeroSlideTextBlock>[];
    final transformRaw = m['imageTransform'];
    return HeroSlide(
      brand: (m['brandLabel'] ?? m['eyebrow'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      subtitle: (m['subtitle'] ?? '') as String,
      imageUrl: (m['imageUrl'] ?? '') as String,
      bgColor: _parseColor(m['bgColor'] as String?, fallback: AppColors.heroPanel),
      accent: _parseColor(m['accentColor'] as String?, fallback: AppColors.brand),
      template: HeroSlideTemplate.fromWire(m['template'] as String?),
      imageFit: HeroImageFit.fromWire(m['imageFit'] as String?),
      // Phase 6 — freeform payload. Defaults to templated when absent,
      // so legacy clients that don't know about FREEFORM still render
      // the slide the merchant's templated fallback would have produced.
      mode: HeroSlideMode.fromWire(m['mode'] as String?),
      textBlocks: blocks,
      imageTransform: transformRaw is Map<String, dynamic>
          ? HeroSlideImageTransform.fromJson(transformRaw)
          : null,
      ctaText: m['ctaText'] as String?,
      ctaTarget: m['ctaTarget'] as String?,
      bannerId: _asInt(m['id']),
    );
  }

  // ── Banner → AdCard ───────────────────────────────────────────────

  static AdCard _adCardFromBanner(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return AdCard(
      bannerId: (m['id'] as num).toInt(),
      brand: (m['brandLabel'] ?? m['eyebrow'] ?? '') as String,
      headline: (m['title'] ?? '') as String,
      cta: (m['ctaText'] ?? m['subtitle'] ?? '') as String,
      imageUrl: (m['imageUrl'] ?? '') as String,
      bgColor: _parseColor(m['bgColor'] as String?, fallback: AppColors.heroPanel),
      ctaTarget: m['ctaTarget'] as String?,
    );
  }

  // ── BrandSpotlight ────────────────────────────────────────────────

  static BrandSpotlight _brandFromSpotlight(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    final shop = m['shop'] is Map<String, dynamic>
        ? m['shop'] as Map<String, dynamic>
        : null;
    return BrandSpotlight(
      spotlightId: (m['id'] as num).toInt(),
      brand: (shop?['name'] ?? '') as String,
      subtitle: (m['subtitle'] ?? '') as String,
      dealLabel: (m['dealLabel'] ?? '') as String,
      imageUrl: (m['heroImageUrl'] ?? '') as String,
      bgColor: _parseColor(m['bgColor'] as String?, fallback: AppColors.heroPanel),
      ctaTarget: m['ctaTarget'] as String?,
      shopSlug: shop?['slug'] as String?,
    );
  }

  // ── Flash sale ────────────────────────────────────────────────────

  static FlashDealProduct? _flashFromSale(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    final product = m['product'] as Map<String, dynamic>?;
    if (product == null) return null;
    final flashPrice = _asDouble(m['flashPrice']) ?? 0;
    final mrp = _asDouble(product['mrp']) ?? _asDouble(product['sellingPrice']) ?? flashPrice;
    final sold = _asInt(m['soldCount']) ?? 0;
    final limit = _asInt(m['stockLimit']) ?? 0;
    final discount = mrp > 0
        ? ((1 - flashPrice / mrp) * 100).clamp(0, 99).toInt()
        : 0;
    final image = _firstImage(product);
    final endAt = DateTime.tryParse((m['endAt'] ?? '') as String)?.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
    return FlashDealProduct(
      productId: (product['id'] as num).toInt(),
      saleId: (m['id'] as num).toInt(),
      name: (product['name'] ?? '') as String,
      price: _money(flashPrice),
      originalPrice: _money(mrp),
      discountPct: discount,
      imageUrl: image,
      soldPct: limit > 0 ? (sold / limit).clamp(0, 1).toDouble() : 0,
      endAt: endAt,
    );
  }

  // ── Trending ────────────────────────────────────────────────────

  static ProductCard? _productCardFromTrending(dynamic row) {
    final m = row as Map<String, dynamic>;
    final product = m['product'] as Map<String, dynamic>?;
    if (product == null) return null;
    // Sponsored slots come through with `isAd: true` and a
    // `promotionId` set by the backend's injectSponsoredIntoRail.
    final isAd = m['isAd'] == true;
    final promotionId = _asInt(m['promotionId']);
    return _productCardFromProduct(product, isAd: isAd, promotionId: promotionId);
  }

  static ProductCard? _productCardFromProduct(
    Map<String, dynamic> p, {
    bool isAd = false,
    int? promotionId,
  }) {
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
      isAd: isAd,
      promotionId: promotionId,
      shopSlug: shop?['slug'] as String?,
      discountPct: discountPct,
    );
  }

  // ── Collections / curated rails ──────────────────────────────────

  static CollectionTile _collectionTile(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return CollectionTile(
      collectionId: (m['id'] as num).toInt(),
      slug: (m['slug'] ?? '') as String,
      label: (m['title'] ?? '') as String,
      imageUrl: (m['coverImageUrl'] ?? '') as String,
    );
  }

  static List<CuratedRailItem> _curatedRails(
    List<dynamic> bannerRows,
    List<dynamic> collectionRows,
  ) {
    final fromBanners = bannerRows.map((raw) {
      final m = raw as Map<String, dynamic>;
      return CuratedRailItem(
        eyebrow: ((m['eyebrow'] ?? '') as String).toUpperCase(),
        title: (m['title'] ?? '') as String,
        subtitle: (m['subtitle'] ?? '') as String,
        cta: (m['ctaText'] ?? 'Shop now') as String,
        imageUrl: (m['imageUrl'] ?? '') as String,
        bgColor: _parseColor(m['bgColor'] as String?, fallback: AppColors.heroPanel),
        accentColor: _parseColor(m['accentColor'] as String?, fallback: AppColors.brand),
        ctaTarget: m['ctaTarget'] as String?,
      );
    });
    // Collections become curated rails when there's no banner content
    // — guarantees the section has something to show even before a
    // platform admin has curated the home page.
    final fromCollections = collectionRows.take(4).map((raw) {
      final m = raw as Map<String, dynamic>;
      return CuratedRailItem(
        collectionSlug: (m['slug'] ?? '') as String,
        eyebrow: ((m['eyebrow'] ?? 'EDITORIAL') as String).toUpperCase(),
        title: (m['title'] ?? '') as String,
        subtitle: (m['subtitle'] ?? '') as String,
        cta: (m['ctaText'] ?? 'Explore') as String,
        imageUrl: (m['coverImageUrl'] ?? '') as String,
        bgColor: _parseColor(m['bgColor'] as String?, fallback: AppColors.heroPanel),
        accentColor: AppColors.brand,
        ctaTarget: (m['ctaTarget'] ?? 'collection:${m['slug']}') as String,
      );
    });
    return [...fromBanners, ...fromCollections];
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
  /// score from a Prisma row we must accept both — using `as num` was
  /// blowing up on the first product card. Returns null on anything
  /// we can't parse so callers fall back to a sensible default.
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

  static Color _parseColor(String? hex, {required Color fallback}) {
    if (hex == null) return fallback;
    final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
    if (m == null) return fallback;
    var raw = m.group(1)!;
    if (raw.length == 6) raw = 'FF$raw';
    return Color(int.parse(raw, radix: 16));
  }

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static String _money(double v) => _inr.format(v);

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
