import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';

/// Global product search across the merchant's full catalog. The
/// backend already supports `?search=` on `/me/catalog/products`, so
/// this provider is a thin debounced wrapper around it that also
/// keeps a small recent-searches list in memory.
///
/// Persistence: not wired yet (no `SharedPreferences` dependency in
/// the customer app). Recent searches survive the session but reset
/// on cold launch — fine for v1, can be promoted to disk later.
class SearchProvider extends ChangeNotifier {
  SearchProvider(this._ds);

  final CatalogRemoteDataSource _ds;

  String _query = '';
  List<CatalogProduct> _results = const [];
  bool _loading = false;
  String? _error;
  final List<String> _recent = <String>[];

  /// Sequence number used to discard stale responses when the user
  /// types faster than the network. Only the latest in-flight request
  /// is allowed to write to [_results].
  int _seq = 0;
  Timer? _debounce;

  String get query => _query;
  List<CatalogProduct> get results => _results;
  bool get isLoading => _loading;
  String? get error => _error;
  List<String> get recentSearches => List.unmodifiable(_recent);

  /// Latest non-empty query was committed (submitted via Enter or a
  /// recent-search chip tap). Distinct from a still-typing state.
  bool get hasCommittedQuery => _query.trim().isNotEmpty;

  /// Update the active query and kick off a debounced search.
  /// Empty queries clear results immediately without a network call.
  void setQuery(String q) {
    _query = q;
    notifyListeners();
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      _results = const [];
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }
    _debounce = Timer(AppDurations.searchDebounce, () => _runSearch(trimmed));
  }

  /// Commit the current query to the recent-searches list. Called
  /// when the user submits (Enter, tap a result, etc.). De-dupes and
  /// caps at 8 entries (NN/g: more than ~8 chips overwhelms scan).
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

  /// Apply one of the recent-searches chips. Skips the debounce so
  /// the chip tap feels instant.
  void applyRecent(String value) {
    _debounce?.cancel();
    _query = value;
    notifyListeners();
    _runSearch(value.trim());
  }

  void clearRecent() {
    _recent.clear();
    notifyListeners();
  }

  void clear() {
    _debounce?.cancel();
    _query = '';
    _results = const [];
    _error = null;
    _loading = false;
    notifyListeners();
  }

  Future<void> _runSearch(String trimmed) async {
    if (trimmed.isEmpty) return;
    final seq = ++_seq;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _ds.listProducts(search: trimmed, limit: 40);
      if (seq != _seq) return;
      _results = res.data;
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
