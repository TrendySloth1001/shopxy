import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/data/datasources/merchant_carousel_remote_data_source.dart';
import 'package:shopxy/features/carousel/data/models/banner_product.dart';

/// State for the merchant's own carousel manager. Mirrors the
/// AdminBannersProvider shape but talks to /me/banners and only
/// holds HERO-placement slides — a merchant doesn't get to seed the
/// platform ad strip or curated rail from this surface.
class MerchantCarouselProvider extends ChangeNotifier {
  MerchantCarouselProvider(this._ds);
  final MerchantCarouselRemoteDataSource _ds;

  final List<AdminBanner> _slides = [];
  bool _isLoading = false;
  String? _error;

  List<AdminBanner> get slides {
    final out = List<AdminBanner>.from(_slides);
    out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(out);
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _ds.list();
      _slides
        ..clear()
        ..addAll(rows);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AdminBanner?> create(Map<String, dynamic> body) async {
    try {
      // Lock placement to HERO on the wire — the carousel manager
      // only exposes hero slides; the merchant doesn't need to know
      // the placement enum exists.
      final created = await _ds.create({...body, 'placement': 'HERO'});
      _slides.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<AdminBanner?> update(int id, Map<String, dynamic> body) async {
    try {
      final updated = await _ds.update(id, body);
      final i = _slides.indexWhere((b) => b.id == id);
      if (i >= 0) _slides[i] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _ds.delete(id);
      _slides.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Convenience pass-throughs so widgets can read/write a slide's
  /// product list without holding the data source directly. Errors
  /// surface via the returned Future so the editor can decide whether
  /// to retry or roll back the in-memory state.
  Future<List<BannerProductLink>> loadLinkedProducts(int bannerId) {
    return _ds.listProducts(bannerId);
  }

  Future<List<BannerProductLink>> replaceLinkedProducts(
    int bannerId,
    List<BannerProductLink> items,
  ) {
    return _ds.replaceProducts(bannerId, items);
  }
}
