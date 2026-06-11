import 'package:flutter/foundation.dart';
import 'package:shopxy/features/promotions/data/datasources/promotions_remote_data_source.dart';
import 'package:shopxy/features/promotions/data/models/promotion.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class PromotionsProvider extends ChangeNotifier {
  PromotionsProvider(this._ds);
  final PromotionsRemoteDataSource _ds;

  final List<Promotion> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Promotion> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _ds.list();
      _items
        ..clear()
        ..addAll(list);
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Promotion?> create(Map<String, dynamic> body) async {
    try {
      final created = await _ds.create(body);
      _items.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<Promotion?> update(int id, Map<String, dynamic> body) async {
    try {
      final updated = await _ds.update(id, body);
      final i = _items.indexWhere((p) => p.id == id);
      if (i >= 0) _items[i] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancel(int id) async {
    try {
      await _ds.cancel(id);
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
    // Refresh in a separate try so a failed reload still surfaces an
    // error (the cancel itself already succeeded server-side, but the
    // user needs to know the list isn't in sync).
    try {
      await load();
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
    }
    return true;
  }
}
