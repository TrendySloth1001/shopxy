import 'package:flutter/foundation.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_merchant.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

class LinkedMerchantsProvider extends ChangeNotifier {
  LinkedMerchantsProvider(this._ds);
  final MeRemoteDataSource _ds;

  List<LinkedMerchant> _items = const [];
  bool _loading = false;
  String? _error;
  bool _hasLoaded = false;

  List<LinkedMerchant> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get hasLoaded => _hasLoaded;
  bool get isEmpty => _items.isEmpty;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _ds.linkedShops();
      _hasLoaded = true;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _items = const [];
    _error = null;
    _hasLoaded = false;
    notifyListeners();
  }
}
