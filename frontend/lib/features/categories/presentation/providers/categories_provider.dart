import 'package:flutter/material.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/shared/utils/error_text.dart';

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
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTree() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tree = await _dataSource.getTree(activeOnly: true);
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
