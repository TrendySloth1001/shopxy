import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// True when a non-empty query has been submitted (Enter or chip
  /// tap). Used by the page to decide whether to render the idle
  /// "recent + hints" panel or the results list.
  bool get hasCommittedQuery => _query.trim().isNotEmpty;

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
      final res = await _ds.search(trimmed);
      if (seq != _seq) return;
      _results = res.results;
      _semantic = res.semantic;
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
