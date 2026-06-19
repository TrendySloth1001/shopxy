import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

/// What the Razorpay sheet resolved to on the client.
enum RazorpayOutcome { success, failed, dismissed }

class RazorpayResult {
  const RazorpayResult(this.outcome, {this.paymentId, this.message});

  final RazorpayOutcome outcome;
  final String? paymentId;
  final String? message;

  bool get isSuccess => outcome == RazorpayOutcome.success;
}

/// Wraps `razorpay_flutter`'s event-based API in a single awaitable [open] call.
/// Ported from the customer app (`customer/lib/features/payments/`); the merchant
/// POS "Online" tender uses it. Pass the server-issued `clientParams` (key /
/// order_id / amount / currency) from the `payOnline` POS command.
///
/// IMPORTANT: a `success` result here is only the client-side handshake. The
/// BACKEND WEBHOOK / the `syncOnline` POS command is the source of truth that
/// money moved and flips the sale to CHECKED_OUT — treat client success as
/// "sheet completed, now sync the sale".
class RazorpayCheckout {
  Future<RazorpayResult> open({
    required Map<String, dynamic> clientParams,
    String name = 'ShopXY',
    String? description,
  }) {
    final razorpay = Razorpay();
    final completer = Completer<RazorpayResult>();

    void finish(RazorpayResult result) {
      if (!completer.isCompleted) completer.complete(result);
      razorpay.clear(); // tear down native listeners; safe once
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse resp) {
      finish(RazorpayResult(RazorpayOutcome.success, paymentId: resp.paymentId));
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse resp) {
      final dismissed = resp.code == Razorpay.PAYMENT_CANCELLED;
      finish(RazorpayResult(
        dismissed ? RazorpayOutcome.dismissed : RazorpayOutcome.failed,
        message: resp.message,
      ));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse resp) {
      // Final outcome still arrives via SUCCESS/ERROR; don't complete here.
    });

    razorpay.open(<String, dynamic>{
      'key': clientParams['key'],
      'order_id': clientParams['order_id'],
      'amount': clientParams['amount'],
      'currency': clientParams['currency'] ?? 'INR',
      'name': name,
      'description': ?description,
      'retry': <String, dynamic>{'enabled': true, 'max_count': 1},
    });

    return completer.future;
  }
}
