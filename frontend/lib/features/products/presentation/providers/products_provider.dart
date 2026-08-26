import 'package:flutter/material.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/data/models/product_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class ProductsProvider extends ChangeNotifier {
  ProductsProvider(this._dataSource);
  final ProductsRemoteDataSource _dataSource;

  List<Product> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _total = 0;
  int _page = 1;
  String _search = '';
  String? _categoryFilter;
  bool _lowStockOnly = false;
  bool _outOfStockOnly = false;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get total => _total;
  int get page => _page;
  String get search => _search;
  String? get categoryFilter => _categoryFilter;
  bool get lowStockOnly => _lowStockOnly;
  bool get outOfStockOnly => _outOfStockOnly;
  bool get hasMore => _products.length < _total;

  void reset() {
    _products = [];
    _isLoading = false;
    _isLoadingMore = false;
    _error = null;
    _total = 0;
    _page = 1;
    _search = '';
    _categoryFilter = null;
    _lowStockOnly = false;
    _outOfStockOnly = false;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    _page = 1;
    loadProducts();
  }

  void setCategoryFilter(String? categoryId) {
    _categoryFilter = categoryId;
    _page = 1;
    loadProducts();
  }

  void setLowStockOnly(bool value) {
    _lowStockOnly = value;
    if (value) _outOfStockOnly = false;
    _page = 1;
    loadProducts();
  }

  void setOutOfStockOnly(bool value) {
    _outOfStockOnly = value;
    if (value) _lowStockOnly = false;
    _page = 1;
    loadProducts();
  }

  Future<void> loadProducts({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore) return;
      _isLoadingMore = true;
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
        lowStock: _lowStockOnly ? true : null,
        outOfStock: _outOfStockOnly ? true : null,
        page: _page,
      );

      if (loadMore) {
        _products = [..._products, ...result.products];
      } else {
        _products = result.products;
      }
      _total = result.total;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
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
    String? brand,
    List<String>? imageUrls,
    double? taxPercent,
    String? pricingMode,
    double? stockQuantity,
    double? lowStockThreshold,
    String? unit,
    String? categoryId,
    List<String>? tags,
    List<String>? highlights,
    List<SpecGroup>? specs,
    List<ProductOffer>? offers,
    List<ContentBlock>? contentBlocks,
    List<VariantAxis>? variantAxes,
    List<ProductVariant>? variants,
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
      brand: brand,
      imageUrls: imageUrls,
      taxPercent: taxPercent,
      pricingMode: pricingMode,
      stockQuantity: stockQuantity,
      lowStockThreshold: lowStockThreshold,
      unit: unit,
      categoryId: categoryId,
      tags: tags,
      highlights: highlights,
      specs: specs,
      offers: offers,
      contentBlocks: contentBlocks,
      variantAxes: variantAxes,
      variants: variants,
    );
    final product = await _dataSource.createProduct(data);
    await loadProducts();
    return product;
  }

  Future<Product> updateProduct(String id, Map<String, dynamic> data) async {
    final product = await _dataSource.updateProduct(id, data);
    await loadProducts();
    return product;
  }

  Future<void> deleteProduct(String id) async {
    await _dataSource.deleteProduct(id);
    await loadProducts();
  }
}
