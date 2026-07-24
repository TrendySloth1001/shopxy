import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/datasources/admin_banners_remote_data_source.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/shared/utils/error_text.dart';

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
      // Walk every page so an admin platform with > 100 banners doesn't
      // silently truncate the manager view. Capped at 50 iterations
      // (5k banners) as a runaway-guard — past that we'd want a real
      // virtual list anyway.
      _banners.clear();
      int? cursor;
      var pages = 0;
      do {
        final page = await _ds.list(limit: 100, cursor: cursor);
        _banners.addAll(page.data);
        cursor = page.nextCursor;
        pages++;
      } while (cursor != null && pages < 50);
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

  Future<AdminBanner?> update(String id, Map<String, dynamic> body) async {
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

  Future<bool> delete(String id) async {
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
}
