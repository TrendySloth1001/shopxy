import 'package:flutter/foundation.dart';

import 'package:shopxy_customer/features/gst/data/datasources/gst_profile_remote_data_source.dart';
import 'package:shopxy_customer/features/gst/domain/entities/gst_profile.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

class GstProfileProvider extends ChangeNotifier {
  GstProfileProvider(this._ds);
  final GstProfileRemoteDataSource _ds;

  GstProfile _profile = const GstProfile.empty();
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  GstProfile get profile => _profile;
  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;
  bool get canClaimGst => _profile.isComplete;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _ds.fetch();
      _loaded = true;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or the server's rejection message. The GSTIN
  /// checksum runs server-side, so a failure here is a real answer to show
  /// the user rather than something to retry.
  Future<String?> save({required String? gstin, String? legalName}) async {
    _error = null;
    try {
      _profile = await _ds.save(gstin: gstin, legalName: legalName);
      _loaded = true;
      notifyListeners();
      return null;
    } on GstProfileRejected catch (e) {
      return e.message;
    } catch (e) {
      return friendlyError(e);
    }
  }

  void clear() {
    _profile = const GstProfile.empty();
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
