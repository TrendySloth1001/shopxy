import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_mapper.dart';

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
}

class HomeFeedException implements Exception {
  HomeFeedException(this.message);
  final String message;
  @override
  String toString() => message;
}
