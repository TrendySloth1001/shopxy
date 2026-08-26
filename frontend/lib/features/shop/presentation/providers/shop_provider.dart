import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shopxy/features/shop/data/datasources/shop_remote_data_source.dart';
import 'package:shopxy/features/shop/data/models/shop.dart';
import 'package:shopxy/shared/utils/error_text.dart';

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

  void reset() {
    _shop = null;
    _isLoading = false;
    _isSaving = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> createFirstShop(String name) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      _shop = await _ds.createMyShop(name);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _shop = await _ds.getMyShop();
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save({
    String? name,
    Object? tagline = _absent,
    Object? logoUrl = _absent,
    Object? bannerUrl = _absent,
    Object? locationCity = _absent,
    Object? locationState = _absent,
    Object? returnPolicy = _absent,
    Object? shippingPolicy = _absent,
    Object? refundPolicy = _absent,
    Object? vacationMode = _absent,
    Object? vacationMessage = _absent,
    Object? returnsEnabled = _absent,
    Object? returnWindowDays = _absent,
    Object? refundMode = _absent,
    Object? returnPolicyNote = _absent,
    Object? cancellationPolicy = _absent,
    Object? operatingHours = _absent,
    Object? pdfTemplateId = _absent,
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
        locationCity: locationCity,
        locationState: locationState,
        returnPolicy: returnPolicy,
        shippingPolicy: shippingPolicy,
        refundPolicy: refundPolicy,
        vacationMode: vacationMode,
        vacationMessage: vacationMessage,
        returnsEnabled: returnsEnabled,
        returnWindowDays: returnWindowDays,
        refundMode: refundMode,
        returnPolicyNote: returnPolicyNote,
        cancellationPolicy: cancellationPolicy,
        operatingHours: operatingHours,
        pdfTemplateId: pdfTemplateId,
      );
      return true;
    } catch (e) {
      _error = friendlyError(e);
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
      _error = friendlyError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String?> uploadImage(File file) async {
    _error = null;
    try {
      return await _ds.uploadImage(file);
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }
}

const _absent = Object();
