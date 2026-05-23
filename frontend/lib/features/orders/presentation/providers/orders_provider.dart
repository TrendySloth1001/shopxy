import 'package:flutter/foundation.dart';
import 'package:shopxy/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy/features/orders/domain/entities/merchant_order.dart';

class OrdersProvider extends ChangeNotifier {
  OrdersProvider(this._ds);
  final OrdersRemoteDataSource _ds;

  List<MerchantOrder> _orders = const [];
  bool _loading = false;
  String? _error;
  String? _statusFilter; // null = all
  int _pendingCount = 0;

  List<MerchantOrder> get orders => _orders;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;
  int get pendingCount => _pendingCount;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final result = await _ds.list(status: _statusFilter);
      _orders = result.data;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
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
    _statusFilter = value;
    load();
  }

  Future<MerchantOrderDetail> loadDetail(int id) => _ds.detail(id);

  Future<({int invoiceId, String invoiceNo})> confirm(int id, {String? note}) async {
    final result = await _ds.confirm(id, note: note);
    await Future.wait([load(), refreshPendingCount()]);
    return result;
  }

  Future<void> reject(int id, {String? note}) async {
    await _ds.reject(id, note: note);
    await Future.wait([load(), refreshPendingCount()]);
  }
}
