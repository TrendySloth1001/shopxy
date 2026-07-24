import 'package:flutter/foundation.dart';
import 'package:shopxy/features/admin/data/datasources/admin_bank_offers_remote_data_source.dart';
import 'package:shopxy/features/admin/data/models/platform_bank_offer.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class AdminBankOffersProvider extends ChangeNotifier {
  AdminBankOffersProvider(this._ds);
  final AdminBankOffersRemoteDataSource _ds;

  List<AdminPlatformBankOffer> _offers = const [];
  bool _isLoading = false;
  String? _error;

  List<AdminPlatformBankOffer> get offers => _offers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _offers = await _ds.list();
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> create(Map<String, dynamic> body) async {
    await _ds.create(body);
    await load();
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await _ds.update(id, body);
    await load();
  }

  Future<void> deactivate(String id) async {
    await _ds.deactivate(id);
    await load();
  }
}
