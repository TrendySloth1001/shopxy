import 'package:flutter/foundation.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductCatalogue extends ChangeNotifier {
  ProductCatalogue(this._dataSource);
  final ProductsRemoteDataSource _dataSource;

  List<Product> _products = const [];
  List<_Indexed> _index = const [];
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _truncated = false;

  bool get isSearchable => _isLoaded && !_truncated;

  bool get isLoading => _isLoading;

  bool get isTruncated => _truncated;

  int get length => _products.length;

  Future<void> ensureLoaded() async {
    if (_isLoaded || _isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _dataSource.getCatalogue();
      _products = result.products;
      _truncated = result.truncated;
      _index = _truncated ? const [] : result.products.map(_Indexed.of).toList();
      _isLoaded = true;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _products = const [];
    _index = const [];
    _isLoaded = false;
    _isLoading = false;
    _truncated = false;
    notifyListeners();
  }

  List<Product> search(String query, {int limit = 8}) {
    if (!isSearchable) return const [];

    final tokens = _tokenize(query);
    if (tokens.isEmpty) return const [];

    final scored = <({int score, _Indexed row})>[];
    for (final row in _index) {
      final score = row.score(tokens);
      if (score > 0) scored.add((score: score, row: row));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.row.name.compareTo(b.row.name);
    });

    return [
      for (final s in scored.take(limit)) s.row.product,
    ];
  }

  static List<String> _tokenize(String raw) =>
      raw.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
}

class _Indexed {
  _Indexed({
    required this.product,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.words,
  });

  factory _Indexed.of(Product p) {
    final name = p.name.toLowerCase();
    return _Indexed(
      product: p,
      name: name,
      sku: p.sku.toLowerCase(),
      barcode: p.barcode?.toLowerCase() ?? '',
      words: name.split(RegExp(r'[\s\-/,()]+')).where((w) => w.isNotEmpty).toList(),
    );
  }

  final Product product;
  final String name;
  final String sku;
  final String barcode;
  final List<String> words;

  int score(List<String> tokens) {
    var total = 0;
    for (final token in tokens) {
      final s = _scoreToken(token);
      if (s == 0) return 0;
      total += s;
    }
    return total;
  }

  int _scoreToken(String token) {
    if (sku == token || barcode == token) return 1000;
    if (name == token) return 500;
    if (name.startsWith(token)) return 200;
    for (final word in words) {
      if (word.startsWith(token)) return 100;
    }
    if (sku.startsWith(token) || barcode.startsWith(token)) return 80;
    if (name.contains(token)) return 20;
    if (sku.contains(token) || barcode.contains(token)) return 10;
    return 0;
  }
}
