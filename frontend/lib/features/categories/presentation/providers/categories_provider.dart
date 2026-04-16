import 'package:flutter/material.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/data/models/category_dto.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';

class CategoriesProvider extends ChangeNotifier {
  CategoriesProvider(this._dataSource);
  final CategoriesRemoteDataSource _dataSource;

  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => _categories;
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

  Future<void> createCategory({
    required String name,
    String? description,
  }) async {
    final data = CategoryDto.toCreateJson(name: name, description: description);
    await _dataSource.createCategory(data);
    await loadCategories();
  }

  Future<void> updateCategory(int id, {String? name, String? description}) async {
    final data = CategoryDto.toUpdateJson(name: name, description: description);
    await _dataSource.updateCategory(id, data);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _dataSource.deleteCategory(id);
    await loadCategories();
  }
}
