# Customer app — online payments (Razorpay) setup

The checkout "Pay Online" path opens the Razorpay Checkout sheet via the
`razorpay_flutter` native plugin. The Dart side is wired and analyzes clean; the
native build needs the steps below before it runs on a device.

## What's wired (Dart)

- `pubspec.yaml` → `razorpay_flutter: ^1.4.0` (already `flutter pub get`-ed).
- `lib/features/payments/razorpay_checkout.dart` — `RazorpayCheckout.open(...)`
  wraps the SDK's event API in one awaitable call.
- `orders_remote_data_source.dart` → `payForOrder(orderId)` → `POST /me/orders/:id/pay`
  returning `GatewayCheckout` (key/order_id/amount/currency).
- `cart_provider.dart` → `payForOrder` delegate.
- `checkout_page.dart` → a Cash-on-Delivery vs Pay-Online selector; on "Pay
  Online" + Place Order it creates the order, fetches the checkout session, and
  opens the sheet. The order lands either way — the **backend webhook** is the
  source of truth that flips the order to PAID (never the client callback).

## Native config to verify

**Android** (`android/app/build.gradle.kts`)
- `minSdk` currently inherits `flutter.minSdkVersion` (21 on Flutter 3.38) —
  Razorpay needs **≥ 21**. OK as-is; pin `minSdk = 21` if you ever lower it.
- Add Razorpay ProGuard rules if you enable R8/minify for release:
  ```
  -keep class com.razorpay.** {*;}
  -keep class proguard.annotation.** {*;}
  -dontwarn com.razorpay.**
  ```

**iOS** — no manifest changes needed; run `cd ios && pod install` (or
`flutter build ios`) so the Razorpay pod is fetched.

## Test flow (test mode)

1. Backend `.env` already has the `rzp_test_*` keys; the Razorpay dashboard
   webhook must point at `POST <host>/payment-gateway/webhook/razorpay`
   (tunnel `localhost:3003` via ngrok for local testing).
2. In the app: add to cart → Checkout → choose **Pay Online** → Place Order →
   the Razorpay sheet opens. Pay with a
   [test card](https://razorpay.com/docs/payments/payments/test-card-details/).
3. On capture, the webhook runs the ORDER settlement handler →
   `CustomerOrder.paymentStatus = 'PAID'`.

## Notes

- COD remains the default and is unchanged.
- A fully wallet/coupon-covered order has nothing to pay online — the endpoint
  returns `NOTHING_TO_PAY` (the UI should keep COD in that case).
- Escrow / per-seller Route split is NOT part of this flow — the captured money
  sits in the platform account. That's the next increment (`ESCROW_FLOW.md`).
