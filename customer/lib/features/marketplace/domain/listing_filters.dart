import 'package:flutter/foundation.dart';

/// Customer-supplied filter axes for marketplace listings (category,
/// shop, search). All axes are independent; an unset axis is `null`.
@immutable
class ListingFilters {
  const ListingFilters({
    this.priceMin,
    this.priceMax,
    this.ratingMin,
    this.inStock = false,
    this.shopIds = const <int>[],
  });

  final double? priceMin;
  final double? priceMax;
  final double? ratingMin;
  final bool inStock;
  final List<int> shopIds;

  static const ListingFilters none = ListingFilters();

  bool get isEmpty =>
      priceMin == null &&
      priceMax == null &&
      ratingMin == null &&
      !inStock &&
      shopIds.isEmpty;

  /// Number of active filter axes. Drives the filter button's badge.
  int get activeCount {
    var n = 0;
    if (priceMin != null || priceMax != null) n++;
    if (ratingMin != null) n++;
    if (inStock) n++;
    if (shopIds.isNotEmpty) n++;
    return n;
  }

  ListingFilters copyWith({
    Object? priceMin = _undefined,
    Object? priceMax = _undefined,
    Object? ratingMin = _undefined,
    bool? inStock,
    List<int>? shopIds,
  }) {
    return ListingFilters(
      priceMin: identical(priceMin, _undefined) ? this.priceMin : priceMin as double?,
      priceMax: identical(priceMax, _undefined) ? this.priceMax : priceMax as double?,
      ratingMin: identical(ratingMin, _undefined) ? this.ratingMin : ratingMin as double?,
      inStock: inStock ?? this.inStock,
      shopIds: shopIds ?? this.shopIds,
    );
  }

  /// Wire format expected by `/marketplace/categories/:slug/products`
  /// and `/marketplace/shops/:slug/products`. Empty axes are dropped
  /// so URLs stay tidy.
  Map<String, String> toQueryParams() {
    final p = <String, String>{};
    if (priceMin != null) p['priceMin'] = priceMin!.toStringAsFixed(2);
    if (priceMax != null) p['priceMax'] = priceMax!.toStringAsFixed(2);
    if (ratingMin != null) p['ratingMin'] = ratingMin!.toString();
    if (inStock) p['inStock'] = 'true';
    if (shopIds.isNotEmpty) p['shopIds'] = shopIds.join(',');
    return p;
  }

  /// Wire format embedded inside the `filters` object on `POST /search`.
  Map<String, dynamic> toSearchPayload() {
    final p = <String, dynamic>{};
    if (priceMin != null) p['priceMin'] = priceMin;
    if (priceMax != null) p['priceMax'] = priceMax;
    if (ratingMin != null) p['ratingMin'] = ratingMin;
    if (inStock) p['inStock'] = true;
    if (shopIds.isNotEmpty) p['shopIds'] = shopIds;
    return p;
  }

  @override
  bool operator ==(Object other) =>
      other is ListingFilters &&
      other.priceMin == priceMin &&
      other.priceMax == priceMax &&
      other.ratingMin == ratingMin &&
      other.inStock == inStock &&
      listEquals(other.shopIds, shopIds);

  @override
  int get hashCode =>
      Object.hash(priceMin, priceMax, ratingMin, inStock, Object.hashAll(shopIds));
}

const Object _undefined = Object();

/// Facet payload that the server returns alongside listing data when
/// `includeFacets=true`. Drives the filter sheet's chip counts.
@immutable
class ListingFacets {
  const ListingFacets({
    required this.priceMin,
    required this.priceMax,
    required this.gte4Count,
    required this.gte3Count,
    required this.inStockCount,
    required this.brands,
  });

  final double priceMin;
  final double priceMax;
  final int gte4Count;
  final int gte3Count;
  final int inStockCount;
  final List<BrandFacet> brands;

  static const ListingFacets empty = ListingFacets(
    priceMin: 0,
    priceMax: 0,
    gte4Count: 0,
    gte3Count: 0,
    inStockCount: 0,
    brands: <BrandFacet>[],
  );

  factory ListingFacets.fromJson(Map<String, dynamic> j) {
    final ratingBuckets = j['ratingBuckets'] as Map<String, dynamic>? ?? const {};
    return ListingFacets(
      priceMin: (j['priceMin'] as num?)?.toDouble() ?? 0,
      priceMax: (j['priceMax'] as num?)?.toDouble() ?? 0,
      gte4Count: (ratingBuckets['gte4'] as num?)?.toInt() ?? 0,
      gte3Count: (ratingBuckets['gte3'] as num?)?.toInt() ?? 0,
      inStockCount: (j['inStockCount'] as num?)?.toInt() ?? 0,
      brands: ((j['brands'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BrandFacet.fromJson)
          .toList(),
    );
  }
}

@immutable
class BrandFacet {
  const BrandFacet({
    required this.shopId,
    required this.name,
    required this.slug,
    required this.count,
  });

  final int shopId;
  final String name;
  final String slug;
  final int count;

  factory BrandFacet.fromJson(Map<String, dynamic> j) => BrandFacet(
        shopId: (j['shopId'] as num).toInt(),
        name: j['name'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}
