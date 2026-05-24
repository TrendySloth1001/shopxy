import 'package:flutter/foundation.dart';
import 'package:shopxy/features/analytics/data/datasources/analytics_remote_data_source.dart';
import 'package:shopxy/features/analytics/data/models/analytics.dart';

enum AnalyticsSortKey {
  product,
  impressions,
  taps,
  views,
  addToCart,
  purchases,
  ctr,
  cvr,
}

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsProvider(this._ds);
  final AnalyticsRemoteDataSource _ds;

  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();
  AnalyticsSortKey _sortKey = AnalyticsSortKey.purchases;
  bool _sortAsc = false;
  ProductAnalytics? _data;
  bool _isLoading = false;
  String? _error;

  DateTime get from => _from;
  DateTime get to => _to;
  AnalyticsSortKey get sortKey => _sortKey;
  bool get sortAsc => _sortAsc;
  ProductAnalytics? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Sorted view of the loaded rows. Sort happens client-side — small N
  /// (one row per shop product) and avoids a round trip per column tap.
  List<ProductAnalyticsRow> get sortedProducts {
    if (_data == null) return const [];
    final rows = [..._data!.products];
    int cmp(ProductAnalyticsRow a, ProductAnalyticsRow b) {
      int r;
      switch (_sortKey) {
        case AnalyticsSortKey.product:
          r = a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
          break;
        case AnalyticsSortKey.impressions:
          r = a.impressions.compareTo(b.impressions);
          break;
        case AnalyticsSortKey.taps:
          r = a.taps.compareTo(b.taps);
          break;
        case AnalyticsSortKey.views:
          r = a.views.compareTo(b.views);
          break;
        case AnalyticsSortKey.addToCart:
          r = a.addToCart.compareTo(b.addToCart);
          break;
        case AnalyticsSortKey.purchases:
          r = a.purchases.compareTo(b.purchases);
          break;
        case AnalyticsSortKey.ctr:
          r = a.ctr.compareTo(b.ctr);
          break;
        case AnalyticsSortKey.cvr:
          r = a.cvr.compareTo(b.cvr);
          break;
      }
      return _sortAsc ? r : -r;
    }
    rows.sort(cmp);
    return rows;
  }

  void setRange(DateTime from, DateTime to) {
    _from = from;
    _to = to;
    load();
  }

  void sortBy(AnalyticsSortKey key) {
    if (_sortKey == key) {
      _sortAsc = !_sortAsc;
    } else {
      _sortKey = key;
      _sortAsc = false; // most numeric columns are most-useful desc first
    }
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _ds.getProducts(from: _from, to: _to);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FlashDealAnalytics?> loadFlashDeal(int id) async {
    try {
      return await _ds.getFlashDeal(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
