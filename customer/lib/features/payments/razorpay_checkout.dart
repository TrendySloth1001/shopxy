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

/// Wraps `razorpay_flutter`'s event-based API in a single awaitable [open]
/// call. Pass the server-issued `clientParams` (key / order_id / amount /
/// currency) from `POST /me/orders/:id/pay`.
///
/// IMPORTANT: a `success` result here is only the client-side handshake. The
/// BACKEND WEBHOOK is the source of truth that money actually moved and is
/// what flips the order to PAID. Treat client success as "sheet completed,
/// now refresh the order from the server", not as proof of payment.
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
      // Tear down native listeners; safe to call once.
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse resp) {
      finish(RazorpayResult(RazorpayOutcome.success, paymentId: resp.paymentId));
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse resp) {
      // PAYMENT_CANCELLED (code 2) = the user dismissed the sheet.
      final dismissed = resp.code == Razorpay.PAYMENT_CANCELLED;
      finish(RazorpayResult(
        dismissed ? RazorpayOutcome.dismissed : RazorpayOutcome.failed,
        message: resp.message,
      ));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse resp) {
      // The buyer chose an external UPI/wallet app; the final outcome still
      // arrives via SUCCESS/ERROR, so we don't complete here.
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
