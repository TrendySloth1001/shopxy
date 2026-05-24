import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/home_v2/data/datasources/home_feed_remote_data_source.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_mapper.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_models.dart';

enum HomeFeedStatus { idle, loading, ready, error }

/// Owns the home tab's data + lifecycle.
///
/// The provider exposes one observable feed; the page binds to it and
/// re-renders sections as data arrives. The public `/home/feed` call
/// fires regardless of auth state; the `/me/home/personalized` call
/// follows when an access token is present (the data source returns
/// empty lists for 401 so we don't need to check auth twice).
class HomeFeedProvider extends ChangeNotifier {
  HomeFeedProvider(this._remote);
  final HomeFeedRemoteDataSource _remote;

  HomeFeedStatus _status = HomeFeedStatus.idle;
  String? _error;
  HomeFeed _feed = HomeFeed.empty;
  bool _personalizedInFlight = false;

  HomeFeedStatus get status => _status;
  String? get error => _error;
  HomeFeed get feed => _feed;
  bool get hasData => _status == HomeFeedStatus.ready;
  bool get isLoading => _status == HomeFeedStatus.loading;

  /// Whether the user has seen anything yet. Used by the page to choose
  /// between "first paint" skeletons and "background refresh" indicators.
  bool get isInitial => _feed == HomeFeed.empty;

  /// Initial load. Public feed first (fast, no auth needed) then layer
  /// personalised data on top once that comes back. A failure on the
  /// personalised call doesn't break the page — the main feed stays.
  Future<void> load({bool force = false}) async {
    if (_status == HomeFeedStatus.loading && !force) return;
    _status = HomeFeedStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final next = await _remote.feed();
      _feed = next;
      _status = HomeFeedStatus.ready;
      notifyListeners();
      // Fire personalised load in the background — don't block first
      // paint on it.
      unawaited(_loadPersonalized());
    } catch (e) {
      _status = HomeFeedStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  /// Re-fetch personalised data only (e.g. after the user logs in).
  Future<void> refreshPersonalized() => _loadPersonalized();

  /// Reset to anonymous state — called when the user signs out so the
  /// stale recently-viewed / for-you rows clear immediately.
  void clearPersonalized() {
    _feed = _feed.copyWith(recommended: const [], recentlyViewed: const []);
    notifyListeners();
  }

  Future<void> _loadPersonalized() async {
    if (_personalizedInFlight) return;
    _personalizedInFlight = true;
    try {
      final p = await _remote.personalized();
      _feed = _feed.copyWith(
        recommended: List.from(p.recommended.whereType<ProductCard>()),
        recentlyViewed: List.from(p.recentlyViewed.whereType<ProductCard>()),
      );
      notifyListeners();
    } catch (_) {
      // Personal data is supplementary — failing here mustn't kill the
      // main feed. Swallow + log to console in debug.
    } finally {
      _personalizedInFlight = false;
    }
  }
}

/// Local stand-in for `package:async`'s `unawaited` — avoids pulling
/// in another dependency for one call site.
void unawaited(Future<void> f) {
  f.then((_) {}, onError: (_) {});
}
