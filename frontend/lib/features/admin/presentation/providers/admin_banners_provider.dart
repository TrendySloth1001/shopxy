import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/datasources/admin_banners_remote_data_source.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';

class AdminBannersProvider extends ChangeNotifier {
  AdminBannersProvider(this._ds);
  final AdminBannersRemoteDataSource _ds;

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
      // Admin curates a small set of banners — current ceiling is 100
      // per fetch. If the platform ever exceeds that, expose page.cursor
      // through this provider and add a "load more" affordance; for now
      // the response is consciously single-page and the editor warns if
      // it sees a non-null cursor.
      final page = await _ds.list(limit: 100);
      _banners
        ..clear()
        ..addAll(page.data);
      if (page.nextCursor != null) {
        _error = 'Banner list truncated at 100. Wire cursor paging.';
      }
    } catch (e) {
      _error = e.toString();
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
      _error = e.toString();
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
      _error = e.toString();
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
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
