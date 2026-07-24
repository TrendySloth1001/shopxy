import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

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
      _error = friendlyError(e);
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
      _invoiceError[key] = friendlyError(e);
    } finally {
      _invoiceLoading[key] = false;
      notifyListeners();
    }
  }

  Future<ShopInvoiceDetail> loadInvoiceDetail(LinkedShop s, String id) {
    return _ds.invoiceDetail(s, id);
  }

  /// Per-shop cache of quotations the shop sent this customer.
  final Map<String, List<ShopQuotation>> _quotationCache = {};
  final Map<String, bool> _quotationLoading = {};
  final Map<String, String?> _quotationError = {};

  List<ShopQuotation>? quotationsFor(LinkedShop s) => _quotationCache[_key(s)];
  bool isLoadingQuotations(LinkedShop s) => _quotationLoading[_key(s)] ?? false;
  String? quotationErrorFor(LinkedShop s) => _quotationError[_key(s)];

  int pendingQuotationCount(LinkedShop s) =>
      (_quotationCache[_key(s)] ?? const [])
          .where((q) => q.isPending)
          .length;

  Future<void> loadQuotations(LinkedShop s) async {
    if (s.role != ShopRole.party) return;
    final key = _key(s);
    _quotationLoading[key] = true;
    _quotationError[key] = null;
    notifyListeners();
    try {
      _quotationCache[key] = await _ds.quotations(s);
    } catch (e) {
      _quotationError[key] = friendlyError(e);
    } finally {
      _quotationLoading[key] = false;
      notifyListeners();
    }
  }

  /// Accept a quotation → it becomes a confirmed invoice. Refreshes the
  /// quotation list + the invoice ledger. Throws on failure.
  Future<void> acceptQuotation(LinkedShop s, String quotationId) async {
    await _ds.acceptQuotation(s, quotationId);
    await loadQuotations(s);
    await loadInvoices(s);
  }

  Future<void> declineQuotation(
    LinkedShop s,
    String quotationId, {
    String? declineNote,
  }) async {
    await _ds.declineQuotation(s, quotationId, declineNote: declineNote);
    await loadQuotations(s);
  }

  /// Build a basket and ask the shop for a quote. Refreshes the list. Throws.
  Future<void> requestQuotation(
    LinkedShop s, {
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    await _ds.requestQuotation(s, items: items, note: note);
    await loadQuotations(s);
  }

  /// Withdraw a still-pending quote request. Refreshes the list. Throws.
  Future<void> cancelQuotation(LinkedShop s, String quotationId) async {
    await _ds.cancelQuotation(s, quotationId);
    await loadQuotations(s);
  }

  /// Raw PDF bytes for a quotation (for the share/save sheet). Throws.
  Future<Uint8List> downloadQuotationPdf(LinkedShop s, String quotationId) =>
      _ds.downloadQuotationPdf(s, quotationId);

  void reset() {
    _shops = const [];
    _loaded = false;
    _linkedHint = false;
    _invoiceCache.clear();
    _invoiceLoading.clear();
    _invoiceError.clear();
    _quotationCache.clear();
    _quotationLoading.clear();
    _quotationError.clear();
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
