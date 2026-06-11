import 'package:flutter/foundation.dart';
import 'package:shopxy/features/spotlight/data/datasources/spotlight_remote_data_source.dart';
import 'package:shopxy/features/spotlight/data/models/spotlight.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class SpotlightProvider extends ChangeNotifier {
  SpotlightProvider(this._ds);
  final SpotlightRemoteDataSource _ds;

  final List<Spotlight> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Spotlight> get items => List.unmodifiable(_items);
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

  Future<Spotlight?> submit(Map<String, dynamic> body) async {
    try {
      final created = await _ds.submit(body);
      _items.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> cancel(int id) async {
    try {
      await _ds.cancel(id);
      _items.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }
}
