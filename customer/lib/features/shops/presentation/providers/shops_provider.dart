import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

const String _kLinkedHintKey = 'shops_linked_party_hint_v1';

class ShopsProvider extends ChangeNotifier {
  ShopsProvider(this._ds);
  final MeRemoteDataSource _ds;

  List<LinkedShop> _shops = const [];
  bool _loading = false;
  String? _error;

  bool _loaded = false;

  bool _linkedHint = false;

  List<LinkedShop> get shops => _shops;
  bool get isLoading => _loading;
  String? get error => _error;

  bool get hasLinkedParty {
    if (_loaded) {
      return _shops.any((s) => s.role == ShopRole.party);
    }
    return _linkedHint;
  }

  Future<void> restoreHint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hint = prefs.getBool(_kLinkedHintKey) ?? false;
      if (hint != _linkedHint) {
        _linkedHint = hint;
        notifyListeners();
      }
    } catch (_) {
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

  Future<void> requestQuotation(
    LinkedShop s, {
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    await _ds.requestQuotation(s, items: items, note: note);
    await loadQuotations(s);
  }

  Future<void> cancelQuotation(LinkedShop s, String quotationId) async {
    await _ds.cancelQuotation(s, quotationId);
    await loadQuotations(s);
  }

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
    // ignore: unawaited_futures
    SharedPreferences.getInstance().then(
      (p) => p.remove(_kLinkedHintKey),
    );
    notifyListeners();
  }
}
