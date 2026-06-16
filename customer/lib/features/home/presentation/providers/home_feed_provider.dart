import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/home/data/datasources/home_feed_remote_data_source.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';

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

  // Endless-scroll state. The home tail is now a plain product grid:
  // each page from `/home/feed/page` appends mapped products (deduped
  // by id) to a flat list the widget renders as a grid.
  final List<ProductCard> _products = [];
  final Set<int> _productIds = {};
  int? _endlessSeed;
  int _endlessPage = 0;
  bool _endlessLoading = false;
  bool _endlessExhausted = false;
  String? _endlessError;
  // Consecutive page-load failures. Three strikes (typically caused
  // by a 429 rate-limit) and we stop hammering — the scroll listener
  // checks `endlessExhausted` and stops calling `loadMore`.
  int _endlessFailureStreak = 0;

  List<ProductCard> get products => List.unmodifiable(_products);
  bool get endlessLoading => _endlessLoading;
  bool get endlessExhausted => _endlessExhausted;
  String? get endlessError => _endlessError;

  /// Incremented after each successful public-feed refresh. Views (the
  /// home page's impression tracker, in particular) cache the last
  /// version they processed so they can decide whether to re-run their
  /// post-frame side-effects without recomputing structural hashes.
  int _feedVersion = 0;
  int get feedVersion => _feedVersion;

  /// Guards [load] so a re-tap on pull-to-refresh, a deep-link arrival,
  /// and an auth-state change can't kick off three parallel loads.
  /// `force: true` still waits on an in-flight load instead of racing.
  Completer<void>? _inFlight;

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
  Future<void> load({bool force = false}) {
    // If a load is in flight, every caller — even force:true — joins
    // the same future. Kicking off a second parallel `_remote.feed()`
    // would interleave its writes with the first and could leave the
    // status stuck in `loading` after the slower of the two finishes.
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<void>();
    _inFlight = completer;
    _runLoad(force: force).whenComplete(() {
      _inFlight = null;
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _runLoad({required bool force}) async {
    _status = HomeFeedStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final next = await _remote.feed();
      _feed = next;
      _feedVersion++;
      _status = HomeFeedStatus.ready;
      // Reset the endless-feed pagination so a refresh re-shuffles.
      _resetEndless();
      notifyListeners();
      // Fire personalised load in the background — don't block first
      // paint on it.
      unawaited(_loadPersonalized().catchError((Object e, StackTrace st) {
        debugPrint('home_feed: personalized load failed: $e');
      }));
      // Prime the endless pipeline with one page so the user doesn't
      // hit a loader as soon as they scroll past the rails.
      unawaited(loadMore());
    } catch (e) {
      _status = HomeFeedStatus.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  void _resetEndless() {
    _products.clear();
    _productIds.clear();
    _endlessSeed = null;
    _endlessPage = 0;
    _endlessLoading = false;
    _endlessExhausted = false;
    _endlessError = null;
    _endlessFailureStreak = 0;
  }

  /// Fetch one more endless-page worth of products and append the new
  /// (deduped) cards. The widget calls this from a scroll listener as
  /// the user nears the tail. Safe to invoke concurrently — re-entrant
  /// calls short-circuit on `_endlessLoading`.
  Future<void> loadMore() async {
    if (_endlessLoading || _endlessExhausted) return;
    if (_status != HomeFeedStatus.ready) return;
    _endlessLoading = true;
    _endlessError = null;
    notifyListeners();
    try {
      final page = await _remote.endlessPage(
        page: _endlessPage,
        seed: _endlessSeed,
      );
      _endlessSeed ??= page.seed;
      _endlessPage = page.nextPage;
      _endlessFailureStreak = 0;
      var added = 0;
      for (final p in page.products.whereType<ProductCard>()) {
        if (_productIds.add(p.productId)) {
          _products.add(p);
          added++;
        }
      }
      // A page that returned nothing new (server out of fresh rows)
      // ends the endless scroll.
      if (added == 0 && page.products.isEmpty) _endlessExhausted = true;
    } catch (e) {
      _endlessFailureStreak++;
      _endlessError = e.toString();
      // 3 consecutive failures (typically rate-limited) → freeze the
      // pump. User can pull-to-refresh to retry from page 0.
      if (_endlessFailureStreak >= 3) _endlessExhausted = true;
    } finally {
      _endlessLoading = false;
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
