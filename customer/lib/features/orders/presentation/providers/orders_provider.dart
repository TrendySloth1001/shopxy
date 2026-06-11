import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

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
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<CustomerOrderDetail> loadDetail(int id) => _ds.detail(id);

  /// Fetch the invoice PDF for one shop-order child. Token is passed
  /// from the page (it lives in TokenManager, which the provider
  /// shouldn't take as a dependency) so the page → provider → DS
  /// boundary stays intact without the page reading the DS directly.
  Future<Uint8List> downloadInvoicePdf({
    required int parentId,
    required int childId,
    required String accessToken,
  }) {
    return _ds.downloadInvoicePdf(
      parentId: parentId,
      childId: childId,
      accessToken: accessToken,
    );
  }

  /// Reorder a previous customer order. Returns the cart-ready items
  /// the page can pass to CartProvider plus any items skipped by the
  /// server (out-of-stock / own-shop).
  Future<
      ({
        List<({CatalogProduct product, double quantity})> items,
        List<({int productId, String productName, String reason})> skipped,
      })> reorder(int parentId) {
    return _ds.reorder(parentId);
  }

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
