import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/home/data/datasources/home_feed_remote_data_source.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';

enum HomeFeedStatus { idle, loading, ready, error }

class HomeFeedProvider extends ChangeNotifier {
  HomeFeedProvider(this._remote);
  final HomeFeedRemoteDataSource _remote;

  HomeFeedStatus _status = HomeFeedStatus.idle;
  String? _error;
  HomeFeed _feed = HomeFeed.empty;
  bool _personalizedInFlight = false;

  final List<ProductCard> _products = [];
  final Set<String> _productIds = {};
  int? _endlessSeed;
  int _endlessPage = 0;
  bool _endlessLoading = false;
  bool _endlessExhausted = false;
  String? _endlessError;
  int _endlessFailureStreak = 0;

  List<ProductCard> get products => List.unmodifiable(_products);
  bool get endlessLoading => _endlessLoading;
  bool get endlessExhausted => _endlessExhausted;
  String? get endlessError => _endlessError;

  int _feedVersion = 0;
  int get feedVersion => _feedVersion;

  Completer<void>? _inFlight;

  HomeFeedStatus get status => _status;
  String? get error => _error;
  HomeFeed get feed => _feed;
  bool get hasData => _status == HomeFeedStatus.ready;
  bool get isLoading => _status == HomeFeedStatus.loading;

  bool get isInitial => _feed == HomeFeed.empty;

  Future<void> load({bool force = false}) {
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
      _resetEndless();
      notifyListeners();
      unawaited(_loadPersonalized().catchError((Object e, StackTrace st) {
        debugPrint('home_feed: personalized load failed: $e');
      }));
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
      if (added == 0 && page.products.isEmpty) _endlessExhausted = true;
    } catch (e) {
      _endlessFailureStreak++;
      _endlessError = e.toString();
      if (_endlessFailureStreak >= 3) _endlessExhausted = true;
    } finally {
      _endlessLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  Future<void> refreshPersonalized() => _loadPersonalized();

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
    } finally {
      _personalizedInFlight = false;
    }
  }
}
