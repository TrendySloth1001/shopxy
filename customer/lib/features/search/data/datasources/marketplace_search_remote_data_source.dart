import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/listing_filters.dart';

/// Adapter for the public marketplace search endpoints.
///
///   POST /search                    — hybrid semantic + FTS ranker
///   GET  /search/autocomplete?q=    — short product/term suggestions
///   GET  /search/hints              — top trending terms (24h, cached)
///
/// All three are public (no auth needed). The hybrid ranker is
/// transparent to the client — the response carries a `semantic`
/// boolean flag so the UI can optionally surface "AI-powered search
/// is on" when it's running.
class MarketplaceSearchRemoteDataSource {
  const MarketplaceSearchRemoteDataSource(this._client);
  final ApiClient _client;

  Future<MarketplaceSearchResult> search(
    String query, {
    int? categoryId,
    int? shopId,
    ListingFilters filters = ListingFilters.none,
    bool includeFacets = false,
    String? sessionId,
  }) async {
    final extraFilters = filters.toSearchPayload();
    final hasAnyFilter =
        categoryId != null || shopId != null || extraFilters.isNotEmpty;
    final Map<String, dynamic> body = {
      'q': query,
      if (hasAnyFilter)
        'filters': {
          'categoryId': ?categoryId,
          'shopId': ?shopId,
          ...extraFilters,
        },
      'sessionId': ?sessionId,
      if (includeFacets) 'includeFacets': true,
    };
    final res = await _client.post('/search', body: body);
    if (res.statusCode != 200) {
      throw Exception('Search failed: ${res.statusCode}');
    }
    return MarketplaceSearchResult.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<({List<MarketplaceSearchHit> products, List<String> terms})>
      autocomplete(String q) async {
    final res = await _client.get(
      '/search/autocomplete',
      queryParameters: {'q': q},
    );
    if (res.statusCode != 200) {
      return (products: <MarketplaceSearchHit>[], terms: <String>[]);
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final products = ((json['products'] as List<dynamic>?) ?? const [])
        .map((e) => MarketplaceSearchHit.minimal(e as Map<String, dynamic>))
        .toList();
    final terms = ((json['terms'] as List<dynamic>?) ?? const [])
        .map((e) => (e as Map<String, dynamic>)['term'] as String)
        .toList();
    return (products: products, terms: terms);
  }

  Future<List<String>> hints() async {
    final res = await _client.get('/search/hints');
    if (res.statusCode != 200) return const [];
    final json = jsonDecode(res.body);
    final list = json is List
        ? json
        : (json as Map<String, dynamic>)['data'] as List<dynamic>? ?? const [];
    return list
        .map((e) => (e as Map<String, dynamic>)['term'] as String)
        .toList();
  }
}

class MarketplaceSearchResult {
  const MarketplaceSearchResult({
    required this.query,
    required this.semantic,
    required this.results,
    this.facets,
  });
  final String query;
  /// True when the backend's hybrid semantic + FTS ranker ran. False
  /// means it fell back to pure FTS (no OPENAI_API_KEY configured or
  /// the embedding call failed).
  final bool semantic;
  final List<MarketplaceSearchHit> results;
  /// Populated only when the request set `includeFacets: true`. The
  /// payload is computed against the unfiltered FTS candidate set so
  /// the chips don't collapse when a filter is applied.
  final ListingFacets? facets;

  factory MarketplaceSearchResult.fromJson(Map<String, dynamic> j) {
    return MarketplaceSearchResult(
      query: j['query'] as String? ?? '',
      semantic: j['semantic'] as bool? ?? false,
      results: ((j['results'] as List<dynamic>?) ?? const [])
          .map((e) => MarketplaceSearchHit.fromJson(e as Map<String, dynamic>))
          .toList(),
      facets: j['facets'] is Map<String, dynamic>
          ? ListingFacets.fromJson(j['facets'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MarketplaceSearchHit {
  const MarketplaceSearchHit({
    required this.id,
    required this.name,
    required this.sku,
    required this.sellingPrice,
    required this.ratingAvg,
    required this.ratingCount,
    required this.imageUrl,
    required this.shopName,
    required this.shopSlug,
    required this.rank,
    this.semanticScore,
    this.ftsScore,
  });

  final int id;
  final String name;
  final String sku;
  final double sellingPrice;
  final double? ratingAvg;
  final int ratingCount;
  final String? imageUrl;
  final String shopName;
  final String shopSlug;
  final double rank;
  final double? semanticScore;
  final double? ftsScore;

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Minimal projection from the autocomplete endpoint which only
  /// returns `{id, name}`. All other fields are nulled/zeroed.
  factory MarketplaceSearchHit.minimal(Map<String, dynamic> j) =>
      MarketplaceSearchHit(
        id: j['id'] as int,
        name: j['name'] as String,
        sku: '',
        sellingPrice: 0,
        ratingAvg: null,
        ratingCount: 0,
        imageUrl: null,
        shopName: '',
        shopSlug: '',
        rank: 0,
      );

  factory MarketplaceSearchHit.fromJson(Map<String, dynamic> j) {
    final shop = (j['shop'] as Map<String, dynamic>?) ?? const {};
    return MarketplaceSearchHit(
      id: j['id'] as int,
      name: j['name'] as String,
      sku: j['sku'] as String? ?? '',
      sellingPrice: _asDouble(j['sellingPrice']) ?? 0,
      ratingAvg: _asDouble(j['ratingAvg']),
      ratingCount: j['ratingCount'] as int? ?? 0,
      imageUrl: j['imageUrl'] as String?,
      shopName: shop['name'] as String? ?? '',
      shopSlug: shop['slug'] as String? ?? '',
      rank: _asDouble(j['rank']) ?? 0,
      semanticScore: _asDouble(j['semanticScore']),
      ftsScore: _asDouble(j['ftsScore']),
    );
  }
}
