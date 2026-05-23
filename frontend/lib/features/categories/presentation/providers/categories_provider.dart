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
    String? iconName,
  }) async {
    final data = CategoryDto.toCreateJson(
      name: name,
      description: description,
      iconName: iconName,
    );
    await _dataSource.createCategory(data);
    await loadCategories();
  }

  /// [clearIcon] = true sends `iconName: null` to wipe the existing icon.
  /// [iconName] = non-null replaces the icon. Passing neither leaves it
  /// alone. This avoids the ambiguity of a single nullable string param.
  Future<void> updateCategory(
    int id, {
    String? name,
    String? description,
    String? iconName,
    bool clearIcon = false,
  }) async {
    final data = CategoryDto.toUpdateJson(
      name: name,
      description: description,
      iconName: iconName,
      clearIcon: clearIcon,
    );
    await _dataSource.updateCategory(id, data);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _dataSource.deleteCategory(id);
    await loadCategories();
  }
}
