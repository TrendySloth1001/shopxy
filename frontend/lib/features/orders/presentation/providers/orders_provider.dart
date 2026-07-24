import 'package:flutter/foundation.dart';
import 'package:shopxy/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy/features/orders/domain/entities/merchant_order.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class OrdersProvider extends ChangeNotifier {
  OrdersProvider(this._ds);
  final OrdersRemoteDataSource _ds;

  List<MerchantOrder> _orders = const [];
  bool _loading = false;
  String? _error;

  String? _statusFilter; // null = all
  String _search = '';
  DateTime? _from;
  DateTime? _to;

  int _pendingCount = 0;

  List<MerchantOrder> get orders => _orders;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;
  String get search => _search;
  DateTime? get from => _from;
  DateTime? get to => _to;
  int get pendingCount => _pendingCount;

  /// Drop the cached inbox + badge on logout / 401-refresh.
  void reset() {
    _orders = const [];
    _loading = false;
    _error = null;
    _statusFilter = null;
    _search = '';
    _from = null;
    _to = null;
    _pendingCount = 0;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final result = await _ds.list(
        status: _statusFilter,
        search: _search,
        from: _from,
        to: _to,
      );
      _orders = result.data;
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPendingCount() async {
    try {
      _pendingCount = await _ds.pendingCount();
      notifyListeners();
    } catch (_) {/* ignore */}
  }

  void setStatusFilter(String? value) {
    if (_statusFilter == value) return;
    _statusFilter = value;
    load();
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    load();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    if (_from == from && _to == to) return;
    _from = from;
    _to = to;
    load();
  }

  void clearFilters() {
    if (_search.isEmpty && _from == null && _to == null) return;
    _search = '';
    _from = null;
    _to = null;
    load();
  }

  Future<MerchantOrderDetail> loadDetail(String id) => _ds.detail(id);

  Future<({String invoiceId, String invoiceNo})> confirm(String id, {String? note}) async {
    final result = await _ds.confirm(id, note: note);
    await Future.wait([load(), refreshPendingCount()]);
    return result;
  }

  Future<void> reject(String id, {String? note}) async {
    await _ds.reject(id, note: note);
    await Future.wait([load(), refreshPendingCount()]);
  }

  /// Post a shipping milestone for a confirmed order. The caller
  /// re-pulls the detail afterwards so the events timeline refreshes.
  Future<void> addShippingEvent(
    String id, {
    required String type,
    String? courier,
    String? awb,
    DateTime? eta,
    String? note,
  }) {
    return _ds.addShippingEvent(
      id,
      type: type,
      courier: courier,
      awb: awb,
      eta: eta,
      note: note,
    );
  }
}
