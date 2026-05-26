import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/marketplace/domain/listing_filters.dart';
import 'package:shopxy_customer/features/search/data/datasources/marketplace_search_remote_data_source.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';

/// Marketplace product search. Hits the public `/search` endpoint
/// (hybrid semantic + FTS ranker on the backend; falls back to
/// pure FTS when the embedding service is disabled).
///
/// The provider also prefetches `/search/hints` once per cold start
/// so the idle state can render a "what people are searching" chip
/// strip without paying a per-open round trip.
class SearchProvider extends ChangeNotifier {
  SearchProvider(this._ds) {
    // Best-effort prime — null on failure leaves the chip strip
    // hidden rather than blowing up the page.
    _ds.hints().then((h) {
      _hints = h;
      notifyListeners();
    }).catchError((_) {});
  }

  final MarketplaceSearchRemoteDataSource _ds;

  String _query = '';
  List<MarketplaceSearchHit> _results = const [];
  bool _semantic = false;
  bool _loading = false;
  String? _error;
  List<String> _hints = const [];
  final List<String> _recent = <String>[];
  ListingFilters _filters = ListingFilters.none;
  ListingFacets? _facets;

  /// Sequence number used to discard stale responses when the user
  /// types faster than the network. Only the latest in-flight request
  /// is allowed to write to [_results].
  int _seq = 0;
  Timer? _debounce;

  String get query => _query;
  List<MarketplaceSearchHit> get results => _results;
  bool get isSemantic => _semantic;
  bool get isLoading => _loading;
  String? get error => _error;
  List<String> get hints => _hints;
  List<String> get recentSearches => List.unmodifiable(_recent);
  ListingFilters get filters => _filters;
  ListingFacets? get facets => _facets;

  /// True when a non-empty query has been submitted (Enter or chip
  /// tap). Used by the page to decide whether to render the idle
  /// "recent + hints" panel or the results list.
  bool get hasCommittedQuery => _query.trim().isNotEmpty;

  void setQuery(String q) {
    _query = q;
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      _results = const [];
      _facets = null;
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }
    // Mark `_loading` synchronously so the UI doesn't flash a stale
    // "No matches for '<q>'" empty-state during the debounce window —
    // [hasCommittedQuery] would already be true while [_results] is
    // still empty if we left _loading=false.
    _loading = true;
    notifyListeners();
    _debounce = Timer(AppDurations.searchDebounce, () => _runSearch(trimmed));
  }

  void commitRecent() {
    final t = _query.trim();
    if (t.isEmpty) return;
    _recent.remove(t);
    _recent.insert(0, t);
    while (_recent.length > 8) {
      _recent.removeLast();
    }
    notifyListeners();
  }

  void applyTerm(String value) {
    _debounce?.cancel();
    _query = value;
    // A new term resets filters + facets so the chip counts match the
    // new candidate set; we'll fetch fresh facets on the next call.
    _filters = ListingFilters.none;
    _facets = null;
    notifyListeners();
    _runSearch(value.trim());
  }

  void setFilters(ListingFilters filters) {
    if (filters == _filters) return;
    _filters = filters;
    notifyListeners();
    final trimmed = _query.trim();
    if (trimmed.isNotEmpty) {
      _runSearch(trimmed);
    }
  }

  void clearRecent() {
    _recent.clear();
    notifyListeners();
  }

  void clear() {
    _debounce?.cancel();
    _query = '';
    _results = const [];
    _filters = ListingFilters.none;
    _facets = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  Future<void> _runSearch(String trimmed) async {
    // Belt-and-braces: callers like `applyTerm` and `setFilters` invoke
    // `_runSearch` directly and would otherwise leave a stale debounced
    // tick scheduled. Cancelling here keeps the seq guard from having
    // to do double duty.
    _debounce?.cancel();
    if (trimmed.isEmpty) return;
    final seq = ++_seq;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Ask for facets only when we don't yet have them for this query.
      // Subsequent filter tweaks reuse the cached facet payload — facets
      // are computed off the unfiltered candidate set so they don't
      // change when filters change.
      final res = await _ds.search(
        trimmed,
        filters: _filters,
        includeFacets: _facets == null,
      );
      if (seq != _seq) return;
      _results = res.results;
      _semantic = res.semantic;
      if (res.facets != null) _facets = res.facets;
    } catch (e) {
      if (seq != _seq) return;
      _error = e.toString().replaceFirst('Exception: ', '');
      _results = const [];
    } finally {
      if (seq == _seq) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
