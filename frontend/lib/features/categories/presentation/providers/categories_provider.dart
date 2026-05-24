import 'package:flutter/material.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';

/// Read-only merchant-side provider. The taxonomy is canonical — it's
/// seeded by the backend from a checked-in manifest, not user-editable.
/// Merchants pick a category when creating a product; the
/// platform-admin surface (a separate page) is the only writer.
class CategoriesProvider extends ChangeNotifier {
  CategoriesProvider(this._dataSource);
  final CategoriesRemoteDataSource _dataSource;

  List<Category> _categories = [];
  List<CategoryNode> _tree = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => _categories;
  List<CategoryNode> get tree => _tree;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _dataSource.getCategories();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tree variant used by the read-only browse page and the picker
  /// sheet. One round-trip, server pre-nests children. Idempotent —
  /// callers that just want a refresh can re-invoke.
  Future<void> loadTree() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tree = await _dataSource.getTree(activeOnly: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
