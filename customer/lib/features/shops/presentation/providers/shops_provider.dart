import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';

class ShopsProvider extends ChangeNotifier {
  ShopsProvider(this._ds);
  final MeRemoteDataSource _ds;

  List<LinkedShop> _shops = const [];
  bool _loading = false;
  String? _error;

  List<LinkedShop> get shops => _shops;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> loadShops() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _shops = await _ds.links();
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
    _invoiceCache.clear();
    _invoiceLoading.clear();
    _invoiceError.clear();
    notifyListeners();
  }
}
