import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/datasources/admin_collections_remote_data_source.dart';
import 'package:shopxy/features/admin/data/models/admin_collection.dart';

class AdminCollectionsProvider extends ChangeNotifier {
  AdminCollectionsProvider(this._ds);
  final AdminCollectionsRemoteDataSource _ds;

  final List<AdminCollectionSummary> _list = [];
  bool _isLoading = false;
  String? _error;

  List<AdminCollectionSummary> get list => List.unmodifiable(_list);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _ds.list();
      _list
        ..clear()
        ..addAll(rows);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AdminCollection?> getOne(int id) async {
    try {
      return await _ds.getOne(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<AdminCollectionSummary?> create(Map<String, dynamic> body) async {
    try {
      final created = await _ds.create(body);
      _list.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<AdminCollectionSummary?> update(int id, Map<String, dynamic> body) async {
    try {
      final updated = await _ds.update(id, body);
      final i = _list.indexWhere((c) => c.id == id);
      if (i >= 0) _list[i] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _ds.delete(id);
      _list.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<AdminCollectionItem>?> replaceItems(
    int id,
    List<({int productId, int position})> items,
  ) async {
    try {
      return await _ds.replaceItems(id, items);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<List<AdminCollectionProduct>> searchProducts(String q) async {
    try {
      return await _ds.searchProducts(q);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return const [];
    }
  }
}
