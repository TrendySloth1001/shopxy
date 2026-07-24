import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/wishlist/data/datasources/wishlist_remote_data_source.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

/// Tracks the user's wishlist. The provider holds:
///   * full [entries] for the dedicated wishlist page (lazy-loaded),
///   * a fast in-memory `Set<int>` of product IDs so heart-icon
///     toggles across the app can rebuild in O(1) without re-fetching.
///
/// Mutations are optimistic — the icon flips instantly; if the server
/// rejects, we roll back and surface an error via [error].
class WishlistProvider extends ChangeNotifier {
  WishlistProvider(this._ds);
  final WishlistRemoteDataSource _ds;

  List<WishlistEntry> _entries = const [];
  final Set<String> _ids = <String>{};
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  List<WishlistEntry> get entries => _entries;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  bool contains(String productId) => _ids.contains(productId);

  /// Loads the full list. Safe to call repeatedly — no-ops while
  /// already loading. Pages that just need [contains] can call
  /// [ensureLoaded] instead.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _entries = await _ds.list();
      _ids
        ..clear()
        ..addAll(_entries.map((e) => e.product.id));
      _loaded = true;
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// One-shot variant: only fetch if we haven't yet. Used by catalog/
  /// detail pages that just need the toggle state.
  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await load();
  }

  /// Optimistic add. The icon flips immediately; on server failure we
  /// restore state and surface an error string the caller can show.
  Future<bool> add(String productId) async {
    if (_ids.contains(productId)) return true;
    _ids.add(productId);
    notifyListeners();
    try {
      await _ds.add(productId);
      // Refresh the entries list lazily so the dedicated page picks
      // up the new row next time it's opened. We don't refetch
      // eagerly — most users add from a list and only open the
      // wishlist page occasionally.
      _loaded = false;
      return true;
    } catch (e) {
      _ids.remove(productId);
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String productId) async {
    if (!_ids.contains(productId)) return true;
    _ids.remove(productId);
    _entries = _entries.where((e) => e.product.id != productId).toList();
    notifyListeners();
    try {
      await _ds.remove(productId);
      return true;
    } catch (e) {
      _ids.add(productId);
      _error = friendlyError(e);
      // Reload so the in-memory entries match the server again.
      _loaded = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggle(String productId) async {
    return _ids.contains(productId) ? remove(productId) : add(productId);
  }

  void reset() {
    _entries = const [];
    _ids.clear();
    _loaded = false;
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
