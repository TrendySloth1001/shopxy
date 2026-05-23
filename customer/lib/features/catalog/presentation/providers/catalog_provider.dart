import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';

class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._ds);
  final CatalogRemoteDataSource _ds;

  List<CatalogProduct> _products = const [];
  List<CatalogCategory> _categories = const [];
  String _search = '';
  int? _categoryId;
  bool _loading = false;
  String? _error;

  List<CatalogProduct> get products => _products;
  List<CatalogCategory> get categories => _categories;
  String get search => _search;
  int? get categoryId => _categoryId;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load({bool refresh = false}) async {
    _loading = true;
    if (refresh) _error = null;
    notifyListeners();
    try {
      final result = await _ds.listProducts(
        search: _search,
        categoryId: _categoryId,
      );
      _products = result.data;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      _categories = await _ds.categories();
      notifyListeners();
    } catch (_) {
      // categories are optional in the UI; surface only if non-fatal
    }
  }

  void setSearch(String value) {
    _search = value;
    load(refresh: true);
  }

  void setCategory(int? id) {
    _categoryId = id;
    load(refresh: true);
  }

  void reset() {
    _products = const [];
    _categories = const [];
    _search = '';
    _categoryId = null;
    notifyListeners();
  }
}
