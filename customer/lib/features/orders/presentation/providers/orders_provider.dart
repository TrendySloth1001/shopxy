import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';

/// Customer-facing orders inbox + detail loader. Sits in front of
/// [OrdersRemoteDataSource]; caches the parent list so list rows
/// re-render after a per-shop cancel without a refetch.
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

  /// Cancel one vendor's slice of a customer order. Patches the cached
  /// parent so the list re-renders the aggregated status. Throws
  /// [CancelOrderException] when the backend rejects so the page can
  /// show targeted copy.
  Future<void> cancelShopOrder({
    required int parentId,
    required int childId,
  }) async {
    await _ds.cancelShopOrder(parentId: parentId, childId: childId);
    // Server is the source of truth for `decidedAt`. The cancel endpoint
    // currently returns 204 so we just flip the status here and let the
    // next list() refresh fill in the timestamp. Once the backend starts
    // returning the canonical row, switch this to use the returned
    // value rather than `DateTime.now()` (clock skew + audit log mismatch).
    _orders = _orders.map((parent) {
      if (parent.id != parentId) return parent;
      final updatedChildren = parent.shopOrders
          .map((child) => child.id == childId
              ? child.copyWith(status: 'CANCELLED')
              : child)
          .toList();
      return parent.copyWith(shopOrders: updatedChildren);
    }).toList();
    notifyListeners();
  }

  void reset() {
    _orders = const [];
    _error = null;
    notifyListeners();
  }
}
