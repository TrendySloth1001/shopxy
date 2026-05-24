import 'package:flutter/foundation.dart';
import 'package:shopxy/features/flash_deals/data/datasources/flash_deals_remote_data_source.dart';
import 'package:shopxy/features/flash_deals/data/models/flash_deal.dart';

class FlashDealsProvider extends ChangeNotifier {
  FlashDealsProvider(this._ds);
  final FlashDealsRemoteDataSource _ds;

  final List<FlashDeal> _all = [];
  bool _isLoading = false;
  String? _error;

  List<FlashDeal> get all => List.unmodifiable(_all);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Bucketed by *current* status — the live `soldCount` from the
  /// server already reflects Redis when available, but the active vs
  /// scheduled vs past split is decided client-side from the window
  /// so the UI stays in sync without an extra request after each tick.
  List<FlashDeal> ofStatus(FlashDealStatus status) {
    final now = DateTime.now();
    return _all.where((d) => d.derivedStatus(now) == status).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // status=all is the merchant default — they want every deal in
      // one fetch so the three tabs render without re-querying when
      // the user swipes between them.
      final list = await _ds.list();
      _all
        ..clear()
        ..addAll(list);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<FlashDeal?> create({
    required int productId,
    required double flashPrice,
    required int stockLimit,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    try {
      final created = await _ds.create(
        productId: productId,
        flashPrice: flashPrice,
        stockLimit: stockLimit,
        startAt: startAt,
        endAt: endAt,
      );
      _all.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e is FlashDealApiException ? e.friendlyMessage : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<FlashDeal?> update(int id, Map<String, dynamic> body) async {
    try {
      final updated = await _ds.update(id, body);
      final i = _all.indexWhere((d) => d.id == id);
      if (i >= 0) _all[i] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e is FlashDealApiException ? e.friendlyMessage : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancel(int id) async {
    try {
      await _ds.cancel(id);
      final i = _all.indexWhere((d) => d.id == id);
      if (i >= 0) {
        _all[i] = FlashDeal(
          id: _all[i].id,
          productId: _all[i].productId,
          flashPrice: _all[i].flashPrice,
          stockLimit: _all[i].stockLimit,
          soldCount: _all[i].soldCount,
          startAt: _all[i].startAt,
          endAt: _all[i].endAt,
          isActive: false,
          product: _all[i].product,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e is FlashDealApiException ? e.friendlyMessage : e.toString();
      notifyListeners();
      return false;
    }
  }
}
