import 'package:flutter/foundation.dart';
import 'package:shopxy/features/caution/data/datasources/caution_remote_data_source.dart';

/// Tracks the submit state for caution deposit/refund/adjust actions so the
/// shared sheet can disable its button and surface errors. History loading is
/// handled page-side (mirrors how PartyDetailPage loads its own data).
class CautionProvider extends ChangeNotifier {
  CautionProvider(this._ds);
  final CautionRemoteDataSource _ds;

  bool _isSubmitting = false;
  String? _error;

  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<double> record({
    required int partyId,
    required String type,
    required double amount,
    required String mode,
    String? modeReference,
    String? note,
  }) async {
    return _run(() => _ds.record(
          partyId: partyId,
          type: type,
          amount: amount,
          mode: mode,
          modeReference: modeReference,
          note: note,
        ));
  }

  Future<double> adjust({
    required int partyId,
    required int invoiceId,
    required double amount,
    String? note,
  }) async {
    return _run(() => _ds.adjust(
          partyId: partyId,
          invoiceId: invoiceId,
          amount: amount,
          note: note,
        ));
  }

  Future<double> forfeit({
    required int partyId,
    required double amount,
    required String gstTreatment,
    double? taxRate,
    String? note,
  }) async {
    return _run(() => _ds.forfeit(
          partyId: partyId,
          amount: amount,
          gstTreatment: gstTreatment,
          taxRate: taxRate,
          note: note,
        ));
  }

  Future<double> _run(Future<double> Function() action) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      final balance = await action();
      _isSubmitting = false;
      notifyListeners();
      return balance;
    } catch (e) {
      _isSubmitting = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
