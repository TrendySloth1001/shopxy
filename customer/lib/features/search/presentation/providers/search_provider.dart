import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/listing_filters.dart';
import 'package:shopxy_customer/features/search/data/datasources/marketplace_search_remote_data_source.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

class SearchProvider extends ChangeNotifier {
  SearchProvider(this._ds) {
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
    _debounce?.cancel();
    if (trimmed.isEmpty) return;
    final seq = ++_seq;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
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
      _error = friendlyError(e);
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
