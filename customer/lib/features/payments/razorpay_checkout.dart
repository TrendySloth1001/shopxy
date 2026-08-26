import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

enum RazorpayOutcome { success, failed, dismissed }

class RazorpayResult {
  const RazorpayResult(this.outcome, {this.paymentId, this.message});

  final RazorpayOutcome outcome;
  final String? paymentId;
  final String? message;

  bool get isSuccess => outcome == RazorpayOutcome.success;
}

class RazorpayCheckout {
  Future<RazorpayResult> open({
    required Map<String, dynamic> clientParams,
    String name = 'ShopXY',
    String? description,
    String? prefillEmail,
    String? prefillContact,
  }) {
    final razorpay = Razorpay();
    final completer = Completer<RazorpayResult>();

    void finish(RazorpayResult result) {
      if (!completer.isCompleted) completer.complete(result);
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse resp) {
      finish(RazorpayResult(RazorpayOutcome.success, paymentId: resp.paymentId));
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse resp) {
      final dismissed = resp.code == Razorpay.PAYMENT_CANCELLED;
      finish(RazorpayResult(
        dismissed ? RazorpayOutcome.dismissed : RazorpayOutcome.failed,
        message: resp.message,
      ));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse resp) {
    });

    razorpay.open(<String, dynamic>{
      'key': clientParams['key'],
      'order_id': clientParams['order_id'],
      'amount': clientParams['amount'],
      'currency': clientParams['currency'] ?? 'INR',
      'name': name,
      'description': ?description,
      'prefill': <String, dynamic>{
        'email': ?prefillEmail,
        'contact': ?prefillContact,
      },
      'retry': <String, dynamic>{'enabled': true, 'max_count': 1},
    });

    return completer.future;
  }
}
