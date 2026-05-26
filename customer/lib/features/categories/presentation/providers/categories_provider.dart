import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';

/// Holds the canonical taxonomy in memory for the customer app. Loaded
/// once at app launch (cheap — single network round-trip, server pre-
/// nests children) and consumed by the home rail, the dedicated
/// Categories page, and the search idle state.
///
/// No mutation methods: customers can't author categories.
class CategoriesProvider extends ChangeNotifier {
  CategoriesProvider(this._ds);
  final CategoriesRemoteDataSource _ds;

  List<CategoryNode> _tree = const [];
  bool _isLoading = false;
  String? _error;

  List<CategoryNode> get tree => _tree;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Top-level (parent) categories — what the home rail and the
  /// landing grid render.
  List<Category> get parents => _tree.map((n) => n.category).toList();

  CategoryNode? findBySlug(String slug) {
    for (final n in _tree) {
      if (n.category.slug == slug) return n;
      for (final c in n.children) {
        if (c.category.slug == slug) return c;
      }
    }
    return null;
  }

  Future<void> load({bool force = false}) async {
    if (_tree.isNotEmpty && !force) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tree = await _ds.getTree();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
