import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/wishlist/data/datasources/wishlist_remote_data_source.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

class WishlistProvider extends ChangeNotifier {
  WishlistProvider(this._ds);
  final WishlistRemoteDataSource _ds;

  List<WishlistEntry> _entries = const [];
  final Set<String> _ids = <String>{};
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  List<WishlistEntry> get entries => _entries;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  bool contains(String productId) => _ids.contains(productId);

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _entries = await _ds.list();
      _ids
        ..clear()
        ..addAll(_entries.map((e) => e.product.id));
      _loaded = true;
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await load();
  }

  Future<bool> add(String productId) async {
    if (_ids.contains(productId)) return true;
    _ids.add(productId);
    notifyListeners();
    try {
      await _ds.add(productId);
      _loaded = false;
      return true;
    } catch (e) {
      _ids.remove(productId);
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String productId) async {
    if (!_ids.contains(productId)) return true;
    _ids.remove(productId);
    _entries = _entries.where((e) => e.product.id != productId).toList();
    notifyListeners();
    try {
      await _ds.remove(productId);
      return true;
    } catch (e) {
      _ids.add(productId);
      _error = friendlyError(e);
      _loaded = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggle(String productId) async {
    return _ids.contains(productId) ? remove(productId) : add(productId);
  }

  void reset() {
    _entries = const [];
    _ids.clear();
    _loaded = false;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
