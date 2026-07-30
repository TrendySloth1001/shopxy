import 'package:flutter/foundation.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

/// The shop's active catalogue, held in memory and searched locally.
///
/// Every product picker used to ask the server per keystroke — debounced, so
/// "sol" cost one round-trip instead of three, but still a round-trip before
/// the merchant saw a single row. On a shop counter that is the difference
/// between billing at the speed of typing and billing at the speed of the
/// network. The list barely changes during a billing session, so it is fetched
/// once and searched in memory.
///
/// Three things this must never do:
///
///   - **Search a partial list.** If the shop has more products than the server
///     will send at once, [isSearchable] is false forever and callers go back
///     to the server. Telling a merchant their own SKU doesn't exist is worse
///     than being slow.
///   - **Serve another user's products.** [reset] is registered with
///     AuthProvider, same as every other provider here.
///   - **Go stale after a write.** A create/update/delete invalidates the
///     `products` cache tag, and main.dart's central listener calls [refresh].
class ProductCatalogue extends ChangeNotifier {
  ProductCatalogue(this._dataSource);
  final ProductsRemoteDataSource _dataSource;

  List<Product> _products = const [];
  List<_Indexed> _index = const [];
  bool _isLoaded = false;
  bool _isLoading = false;
  bool _truncated = false;

  /// Whether local search may answer. False before the first successful load
  /// and false forever for a catalogue too large to hold — in both cases the
  /// caller must ask the server.
  bool get isSearchable => _isLoaded && !_truncated;

  bool get isLoading => _isLoading;

  /// True when the shop is past the server's single-response ceiling. Exposed
  /// so a caller can explain *why* it's still hitting the network.
  bool get isTruncated => _truncated;

  int get length => _products.length;

  /// Load once. Cheap to call from every picker's initState — concurrent calls
  /// share the one in-flight request, and a second call after success is a
  /// no-op.
  Future<void> ensureLoaded() async {
    if (_isLoaded || _isLoading) return;
    await refresh();
  }

  /// Refetch unconditionally. Used by the cache-event listener after a write.
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _dataSource.getCatalogue();
      _products = result.products;
      _truncated = result.truncated;
      // Indexing a truncated catalogue would waste the memory and tempt a
      // future caller into searching it.
      _index = _truncated ? const [] : result.products.map(_Indexed.of).toList();
      _isLoaded = true;
    } catch (_) {
      // Leave the previous catalogue in place — a failed refresh must not
      // empty a list that was working. Callers fall back to the server while
      // `_isLoaded` is false; if it was already true, the stale list is still
      // a better answer than none.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Drop everything. Registered with AuthProvider so user B never sees user
  /// A's products.
  void reset() {
    _products = const [];
    _index = const [];
    _isLoaded = false;
    _isLoading = false;
    _truncated = false;
    notifyListeners();
  }

  /// Best [limit] matches for [query], ranked. Empty when the query is blank
  /// or nothing matches — callers must check [isSearchable] first to tell
  /// "no matches" apart from "can't answer".
  ///
  /// Synchronous by design: it runs inside the text field's onChanged, so
  /// results appear in the same frame as the character.
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
      // Alphabetical within a score band, so the order is stable and the same
      // query never reshuffles between keystrokes.
      return byScore != 0 ? byScore : a.row.name.compareTo(b.row.name);
    });

    return [
      for (final s in scored.take(limit)) s.row.product,
    ];
  }

  static List<String> _tokenize(String raw) =>
      raw.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
}

/// A product with its searchable text folded once at load, rather than on
/// every keystroke. With a few thousand rows this is the difference between
/// a linear scan that's free and one that's felt.
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

  /// 0 when any token fails to match. Every token must hit *something* — so
  /// "blue pen" narrows to blue pens instead of returning every pen.
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
    // A scanned or typed-in-full code is an unambiguous answer and outranks
    // any amount of name similarity.
    if (sku == token || barcode == token) return 1000;
    if (name == token) return 500;
    if (name.startsWith(token)) return 200;
    // Matching the start of any word catches "kg" in "Sugar 1 kg" and lets a
    // merchant type the second word of a product first.
    for (final word in words) {
      if (word.startsWith(token)) return 100;
    }
    if (sku.startsWith(token) || barcode.startsWith(token)) return 80;
    if (name.contains(token)) return 20;
    if (sku.contains(token) || barcode.contains(token)) return 10;
    return 0;
  }
}
