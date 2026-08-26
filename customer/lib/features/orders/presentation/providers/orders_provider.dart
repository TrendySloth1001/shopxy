import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

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
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CustomerOrderDetail> loadDetail(String id) => _ds.detail(id);

  Future<Uint8List> downloadInvoicePdf({
    required String parentId,
    required String childId,
    required String accessToken,
  }) {
    return _ds.downloadInvoicePdf(
      parentId: parentId,
      childId: childId,
      accessToken: accessToken,
    );
  }

  Future<
      ({
        List<({CatalogProduct product, double quantity})> items,
        List<({String productId, String productName, String reason})> skipped,
      })> reorder(String parentId) {
    return _ds.reorder(parentId);
  }

  Future<void> cancelShopOrder({
    required String parentId,
    required String childId,
  }) async {
    await _ds.cancelShopOrder(parentId: parentId, childId: childId);
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
