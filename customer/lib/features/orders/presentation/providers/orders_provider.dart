import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';

class OrdersProvider extends ChangeNotifier {
  OrdersProvider(this._ds);
  final OrdersRemoteDataSource _ds;

  List<CustomerOrder> _orders = const [];
  bool _loading = false;
  String? _error;

  List<CustomerOrder> get orders => _orders;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _orders = await _ds.list();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CustomerOrderDetail> loadDetail(int id) => _ds.detail(id);

  Future<void> cancel(int id) async {
    await _ds.cancel(id);
    _orders = _orders
        .map((o) =>
            o.id == id
                ? CustomerOrder(
                    id: o.id,
                    status: 'CANCELLED',
                    customerName: o.customerName,
                    customerPhone: o.customerPhone,
                    estimatedTotal: o.estimatedTotal,
                    itemCount: o.itemCount,
                    createdAt: o.createdAt,
                    decidedAt: DateTime.now(),
                  )
                : o)
        .toList();
    notifyListeners();
  }

  void reset() {
    _orders = const [];
    _error = null;
    notifyListeners();
  }
}
