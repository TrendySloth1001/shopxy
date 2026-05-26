import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shopxy/features/shop/data/datasources/shop_remote_data_source.dart';
import 'package:shopxy/features/shop/data/models/shop.dart';

class ShopProvider extends ChangeNotifier {
  ShopProvider(this._ds);
  final ShopRemoteDataSource _ds;

  Shop? _shop;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  Shop? get shop => _shop;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  /// Drop the cached shop on logout so user-B doesn't see user-A's
  /// banner / tagline flash during the new session's first paint.
  void reset() {
    _shop = null;
    _isLoading = false;
    _isSaving = false;
    _error = null;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _shop = await _ds.getMyShop();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves only the fields the caller cares about. Each named
  /// parameter that is supplied (including explicit null, meaning
  /// "clear it") is sent; un-supplied fields are left untouched.
  Future<bool> save({
    String? name,
    Object? tagline = _absent,
    Object? logoUrl = _absent,
    Object? bannerUrl = _absent,
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      _shop = await _ds.updateMyShop(
        name: name,
        tagline: tagline,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> togglePublish(bool isPublished) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      _shop = await _ds.setPublished(isPublished);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> uploadImage(File file) async {
    // Reset the sticky `_error` so a previous upload failure doesn't
    // surface alongside a fresh attempt.
    _error = null;
    try {
      return await _ds.uploadImage(file);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}

const _absent = Object();
