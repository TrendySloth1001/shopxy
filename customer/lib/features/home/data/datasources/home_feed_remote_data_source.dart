import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';

/// Talks to the home aggregator. Two thin calls:
///
///   * `feed()` is public — anyone can hit it, used for cold-start.
///   * `personalized()` is auth-only and returns the caller's recently
///     viewed + for-you list. Skipped silently when the user isn't
///     logged in.
class HomeFeedRemoteDataSource {
  const HomeFeedRemoteDataSource(this._client);
  final ApiClient _client;

  Future<HomeFeed> feed() async {
    final res = await _client.get('/home/feed');
    if (res.statusCode != 200) {
      throw HomeFeedException('Failed to load home feed: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return HomeFeedMapper.fromFeed(json);
  }

  /// Returns null on 401 (caller is anonymous) so the provider can just
  /// fall back to the public feed without surfacing an error.
  Future<({List<dynamic> recommended, List<dynamic> recentlyViewed})?>
      personalizedRaw() async {
    final res = await _client.get('/me/home/personalized');
    if (res.statusCode == 401) return null;
    if (res.statusCode != 200) {
      throw HomeFeedException(
        'Failed to load personalised feed: ${res.statusCode}',
      );
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      recommended: (json['recommended'] as List?) ?? const [],
      recentlyViewed: (json['recentlyViewed'] as List?) ?? const [],
    );
  }

  /// Convenience wrapper: returns mapped presentation models, or
  /// (empty, empty) when the caller isn't authenticated.
  Future<({List recommended, List recentlyViewed})> personalized() async {
    final raw = await personalizedRaw();
    if (raw == null) return (recommended: const [], recentlyViewed: const []);
    final mapped = HomeFeedMapper.fromPersonalized({
      'recommended': raw.recommended,
      'recentlyViewed': raw.recentlyViewed,
    });
    return (
      recommended: mapped.recommended,
      recentlyViewed: mapped.recentlyViewed,
    );
  }

  /// Endless-scroll page. The server reshuffles indefinitely so this
  /// only stops returning data if the user is rate-limited (4xx/5xx).
  /// On the very first call pass `seed: null` and the server mints
  /// a fresh one; reuse it on every subsequent page so the rotation
  /// stays consistent across the session.
  Future<EndlessPage> endlessPage({required int page, int? seed, int limit = 16}) async {
    final qp = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (seed != null) 'seed': '$seed',
    };
    final query = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    final res = await _client.get('/home/feed/page?$query');
    if (res.statusCode != 200) {
      throw HomeFeedException('Failed to load endless page: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final products = HomeFeedMapper.fromEndlessPage(
      (json['products'] as List?) ?? const [],
    );
    return EndlessPage(
      products: products,
      seed: (json['seed'] as num).toInt(),
      nextPage: (json['nextPage'] as num).toInt(),
    );
  }
}

class EndlessPage {
  const EndlessPage({required this.products, required this.seed, required this.nextPage});
  final List products;
  final int seed;
  final int nextPage;
}

class HomeFeedException implements Exception {
  HomeFeedException(this.message);
  final String message;
  @override
  String toString() => message;
}
