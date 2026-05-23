import 'package:flutter/foundation.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/domain/entities/payment.dart';

class PaymentsProvider extends ChangeNotifier {
  PaymentsProvider(this._ds);
  final PaymentsRemoteDataSource _ds;

  bool _isSubmitting = false;
  String? _error;

  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<Payment> create({
    required String type,
    required double amount,
    required String mode,
    String? modeReference,
    DateTime? paymentDate,
    int? partyId,
    int? vendorId,
    int? invoiceId,
    String? note,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      final payment = await _ds.createPayment(
        type: type,
        amount: amount,
        mode: mode,
        modeReference: modeReference,
        paymentDate: paymentDate,
        partyId: partyId,
        vendorId: vendorId,
        invoiceId: invoiceId,
        note: note,
      );
      _isSubmitting = false;
      notifyListeners();
      return payment;
    } catch (e) {
      _isSubmitting = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    await _ds.deletePayment(id);
  }
}
