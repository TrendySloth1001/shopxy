import 'package:flutter/material.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/data/models/vendor_dto.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';

class VendorsProvider extends ChangeNotifier {
  VendorsProvider(this._ds);
  final VendorsRemoteDataSource _ds;

  List<Vendor> _vendors = [];
  bool _isLoading = false;
  String? _error;
  String _search = '';

  List<Vendor> get vendors => _vendors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get search => _search;

  Future<void> loadVendors({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (refresh) notifyListeners();
    try {
      _vendors = await _ds.getVendors(search: _search.isNotEmpty ? _search : null);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSearch(String value) {
    _search = value;
    loadVendors(refresh: true);
  }

  Future<Vendor> createVendor({
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
  }) async {
    final vendor = await _ds.createVendor(
      name: name,
      contactName: contactName,
      phone: phone,
      email: email,
      address: address,
      gstin: gstin,
    );
    _vendors = [vendor, ..._vendors];
    notifyListeners();
    return vendor;
  }

  Future<Vendor> updateVendor(int id, {
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    bool? isActive,
  }) async {
    final vendor = await _ds.updateVendor(
      id,
      VendorDto.toUpdateJson(
        name: name,
        contactName: contactName,
        phone: phone,
        email: email,
        address: address,
        gstin: gstin,
        isActive: isActive,
      ),
    );
    _vendors = _vendors.map((v) => v.id == id ? vendor : v).toList();
    notifyListeners();
    return vendor;
  }

  Future<void> deleteVendor(int id) async {
    await _ds.deleteVendor(id);
    _vendors = _vendors.where((v) => v.id != id).toList();
    notifyListeners();
  }
}
