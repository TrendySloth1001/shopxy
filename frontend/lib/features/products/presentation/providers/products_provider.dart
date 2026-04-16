import 'package:flutter/material.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/data/models/product_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductsProvider extends ChangeNotifier {
  ProductsProvider(this._dataSource);
  final ProductsRemoteDataSource _dataSource;

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  int _total = 0;
  int _page = 1;
  String _search = '';
  int? _categoryFilter;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get total => _total;
  int get page => _page;
  String get search => _search;
  int? get categoryFilter => _categoryFilter;
  bool get hasMore => _products.length < _total;

  void setSearch(String value) {
    _search = value;
    _page = 1;
    loadProducts();
  }

  void setCategoryFilter(int? categoryId) {
    _categoryFilter = categoryId;
    _page = 1;
    loadProducts();
  }

  Future<void> loadProducts({bool loadMore = false}) async {
    if (loadMore) {
      _page++;
    } else {
      _page = 1;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _dataSource.getProducts(
        search: _search.isNotEmpty ? _search : null,
        categoryId: _categoryFilter,
        page: _page,
      );

      if (loadMore) {
        _products = [..._products, ...result.products];
      } else {
        _products = result.products;
      }
      _total = result.total;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> lookupByCode(String code) async {
    try {
      return await _dataSource.lookupByCode(code);
    } catch (_) {
      return null;
    }
  }

  Future<Product> createProduct({
    required String name,
    required String sku,
    required double mrp,
    required double sellingPrice,
    required double purchasePrice,
    String? description,
    String? barcode,
    String? hsnCode,
    String? imageUrl,
    double? taxPercent,
    double? stockQuantity,
    double? lowStockThreshold,
    String? unit,
    int? categoryId,
  }) async {
    final data = ProductDto.toCreateJson(
      name: name,
      sku: sku,
      mrp: mrp,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      description: description,
      barcode: barcode,
      hsnCode: hsnCode,
      imageUrl: imageUrl,
      taxPercent: taxPercent,
      stockQuantity: stockQuantity,
      lowStockThreshold: lowStockThreshold,
      unit: unit,
      categoryId: categoryId,
    );
    final product = await _dataSource.createProduct(data);
    await loadProducts();
    return product;
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final product = await _dataSource.updateProduct(id, data);
    await loadProducts();
    return product;
  }

  Future<void> deleteProduct(int id) async {
    await _dataSource.deleteProduct(id);
    await loadProducts();
  }
}
