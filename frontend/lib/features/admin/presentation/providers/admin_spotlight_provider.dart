import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/datasources/admin_spotlight_remote_data_source.dart';
import 'package:shopxy/features/admin/data/models/admin_spotlight.dart';
import 'package:shopxy/features/spotlight/data/models/spotlight.dart';

class AdminSpotlightProvider extends ChangeNotifier {
  AdminSpotlightProvider(this._ds);
  final AdminSpotlightRemoteDataSource _ds;

  SpotlightStatus? _filter = SpotlightStatus.pending;
  final List<AdminSpotlight> _items = [];
  bool _isLoading = false;
  String? _error;

  List<AdminSpotlight> get items => List.unmodifiable(_items);
  SpotlightStatus? get filter => _filter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> setFilter(SpotlightStatus? next) async {
    if (_filter == next) return;
    _filter = next;
    await load();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _ds.list(status: _filter, limit: 100);
      _items
        ..clear()
        ..addAll(page.data);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approve(int id) async {
    try {
      final updated = await _ds.approve(id);
      _replace(updated);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reject(int id, String reason) async {
    try {
      final updated = await _ds.reject(id, reason);
      _replace(updated);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _replace(AdminSpotlight s) {
    final i = _items.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      // If the new status no longer matches the filter, drop the row
      // so the queue stays focused on what's actionable.
      if (_filter != null && s.status != _filter) {
        _items.removeAt(i);
      } else {
        _items[i] = s;
      }
    }
    notifyListeners();
  }
}
