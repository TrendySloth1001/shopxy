import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/banners/data/datasources/merchant_banners_remote_data_source.dart';
import 'package:shopxy/features/banners/data/models/banner_product.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class MerchantBannersProvider extends ChangeNotifier {
  MerchantBannersProvider(this._ds);
  final MerchantBannersRemoteDataSource _ds;

  final List<AdminBanner> _banners = [];
  bool _isLoading = false;
  String? _error;

  List<AdminBanner> get banners => List.unmodifiable(_banners);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns banners grouped by placement, in the canonical placement
  /// order the home page renders them.
  Map<BannerPlacement, List<AdminBanner>> get grouped {
    final out = <BannerPlacement, List<AdminBanner>>{
      BannerPlacement.hero: [],
      BannerPlacement.adStrip: [],
      BannerPlacement.promo: [],
      BannerPlacement.curatedRail: [],
    };
    for (final b in _banners) {
      out[b.placement]!.add(b);
    }
    for (final list in out.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return out;
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _banners
        ..clear()
        ..addAll(await _ds.list());
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AdminBanner?> create(Map<String, dynamic> body) async {
    try {
      final created = await _ds.create(body);
      _banners.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<AdminBanner?> update(int id, Map<String, dynamic> body) async {
    try {
      final updated = await _ds.update(id, body);
      final i = _banners.indexWhere((b) => b.id == id);
      if (i >= 0) _banners[i] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _ds.delete(id);
      _banners.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  /// Curated products pinned to a banner, in display order.
  Future<List<BannerProductRow>> listBannerProducts(int bannerId) =>
      _ds.listBannerProducts(bannerId);

  /// Replaces the entire pinned-product list for a banner. Empty [items]
  /// clears it. Returns the re-read rows (with server-computed sale prices).
  Future<List<BannerProductRow>> replaceBannerProducts(
    int bannerId,
    List<BannerProductInput> items,
  ) =>
      _ds.replaceBannerProducts(bannerId, items);

  /// Drops cached state on logout / 401-refresh so the next user doesn't
  /// momentarily see the previous merchant's banners.
  void reset() {
    _banners.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
