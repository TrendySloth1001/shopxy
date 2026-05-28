import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';

/// Persisted hint of "was the user linked to at least one merchant as
/// a customer (party) when we last checked?" — used to seed the
/// bottom-nav layout decision at cold-start so the very first paint
/// matches the user's previous session. Without this, the app would
/// always default to the unlinked layout and flip to the linked one a
/// few hundred ms later, producing a visible flicker.
const String _kLinkedHintKey = 'shops_linked_party_hint_v1';

class ShopsProvider extends ChangeNotifier {
  ShopsProvider(this._ds);
  final MeRemoteDataSource _ds;

  List<LinkedShop> _shops = const [];
  bool _loading = false;
  String? _error;

  /// Whether [loadShops] has produced an authoritative result this
  /// session (either success or a clean empty list). Until this is
  /// true, [hasLinkedParty] falls back to [_linkedHint] so the UI
  /// renders against the user's last-known state instead of an
  /// optimistic empty.
  bool _loaded = false;

  /// Cached hint restored at boot via [restoreHint]. Updated and
  /// persisted whenever [loadShops] succeeds.
  bool _linkedHint = false;

  List<LinkedShop> get shops => _shops;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Source-of-truth for the bottom-nav layout decision. Prefers the
  /// authoritative answer once we've actually loaded; falls back to
  /// the persisted hint during the cold-start window between mount
  /// and first network round-trip.
  bool get hasLinkedParty {
    if (_loaded) {
      return _shops.any((s) => s.role == ShopRole.party);
    }
    return _linkedHint;
  }

  /// Reads the persisted hint from disk. Called once at app boot
  /// (`main.dart`) BEFORE the shell first builds so the layout
  /// decision is right on the very first paint.
  Future<void> restoreHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hint = prefs.getBool(_kLinkedHintKey) ?? false;
      if (hint != _linkedHint) {
        _linkedHint = hint;
        notifyListeners();
      }
    } catch (_) {
      // Best-effort — a missing/corrupt prefs entry just means we
      // default to "unlinked" until the network resolves.
    }
  }

  Future<void> loadShops() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _shops = await _ds.links();
      _loaded = true;
      final newHint = _shops.any((s) => s.role == ShopRole.party);
      if (newHint != _linkedHint) {
        _linkedHint = newHint;
        // Fire and forget — the in-memory value is the source of
        // truth for this session; disk is just for the next boot.
        // ignore: unawaited_futures
        SharedPreferences.getInstance().then(
          (p) => p.setBool(_kLinkedHintKey, newHint),
        );
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Per-shop invoice caches. Keyed by `${role.name}:${id}` so a single
  /// user being both party + vendor at separate shops never collides.
  final Map<String, List<ShopInvoice>> _invoiceCache = {};
  final Map<String, bool> _invoiceLoading = {};
  final Map<String, String?> _invoiceError = {};

  String _key(LinkedShop s) => '${s.role.name}:${s.id}';

  List<ShopInvoice>? invoicesFor(LinkedShop s) => _invoiceCache[_key(s)];
  bool isLoadingInvoices(LinkedShop s) => _invoiceLoading[_key(s)] ?? false;
  String? invoiceErrorFor(LinkedShop s) => _invoiceError[_key(s)];

  Future<void> loadInvoices(LinkedShop s) async {
    final key = _key(s);
    _invoiceLoading[key] = true;
    _invoiceError[key] = null;
    notifyListeners();
    try {
      _invoiceCache[key] = await _ds.invoices(s);
    } catch (e) {
      _invoiceError[key] = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _invoiceLoading[key] = false;
      notifyListeners();
    }
  }

  Future<ShopInvoiceDetail> loadInvoiceDetail(LinkedShop s, int id) {
    return _ds.invoiceDetail(s, id);
  }

  void reset() {
    _shops = const [];
    _loaded = false;
    _linkedHint = false;
    _invoiceCache.clear();
    _invoiceLoading.clear();
    _invoiceError.clear();
    // Clear the persisted hint too — without this, signing in as a
    // different user on the same device would inherit the previous
    // user's bottom-nav layout for the first frame.
    // ignore: unawaited_futures
    SharedPreferences.getInstance().then(
      (p) => p.remove(_kLinkedHintKey),
    );
    notifyListeners();
  }
}
