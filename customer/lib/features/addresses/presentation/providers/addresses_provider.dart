import 'package:flutter/foundation.dart';

import 'package:shopxy_customer/features/addresses/data/datasources/addresses_remote_data_source.dart';
import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

class AddressesProvider extends ChangeNotifier {
  AddressesProvider(this._ds);
  final AddressesRemoteDataSource _ds;

  List<UserAddress> _items = const [];
  bool _loading = false;
  String? _error;

  List<UserAddress> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;

  UserAddress? get defaultAddress {
    if (_items.isEmpty) return null;
    final defaults = _items.where((a) => a.isDefault);
    if (defaults.isNotEmpty) return defaults.first;
    return _items.first;
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _ds.list();
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<UserAddress?> create(UserAddressInput input) async {
    try {
      final addr = await _ds.create(input);
      try {
        _items = await _ds.list();
      } catch (_) {
        _items = [addr, ..._items];
      }
      notifyListeners();
      return addr;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> setDefault(String id) async {
    try {
      await _ds.setDefault(id);
      _items = [
        for (final a in _items)
          if (a.id == id)
            UserAddress(
              id: a.id,
              fullName: a.fullName,
              phone: a.phone,
              line1: a.line1,
              line2: a.line2,
              city: a.city,
              state: a.state,
              pincode: a.pincode,
              landmark: a.landmark,
              label: a.label,
              isDefault: true,
            )
          else
            UserAddress(
              id: a.id,
              fullName: a.fullName,
              phone: a.phone,
              line1: a.line1,
              line2: a.line2,
              city: a.city,
              state: a.state,
              pincode: a.pincode,
              landmark: a.landmark,
              label: a.label,
              isDefault: false,
            ),
      ];
      notifyListeners();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _ds.delete(id);
      _items = _items.where((a) => a.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  void reset() {
    _items = const [];
    _error = null;
    notifyListeners();
  }
}
