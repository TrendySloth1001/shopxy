# POS UPI-QR payments (P5) — design

> **STATUS — BUILT (2026-06-19).** Shipped as **Razorpay Checkout** (Orders +
> checkout.js / razorpay_flutter), NOT the standalone QR Codes API — the QR Codes
> API returns 404 on this account (not enabled), whereas Orders/Checkout is enabled
> and Razorpay Checkout itself shows a UPI QR + cards. The "Online" tender:
> `payOnline` creates a Razorpay **order** (`initiatePayment`, target `POS`) → the
> till opens Razorpay Checkout with the returned `clientParams` → settles on the
> `payment.captured`/`order.paid` webhook (or the `syncOnline` backstop) via the
> `POS` settlement handler (`settlePaidSaleInTx`, single-sourced with manual
> checkout) → `pos.checkout` broadcast flips both tills to paid.
>
> New/changed: `POS` settlement target + handler; `Sale.AWAITING_PAYMENT` +
> `gateway_payment_id` (migration `20260620190000_add_pos_qr`); WS ops
> `payOnline`/`syncOnline`/`cancelOnline` (`pos.payments.ts`); shared
> `openRazorpayCheckout` ported into merchant-web; `razorpay_flutter` added to the
> merchant Flutter app + `razorpay_checkout.dart` ported; reconcile abandons unpaid
> POS intents. The Route transfer to the merchant's linked account (`pos-split.ts`)
> is gated behind **`ROUTE_SPLIT_ENABLED`** (off by default) — until set, a paid
> order collects to the platform account and the sale still completes.
>
> The standalone QR-Codes provider capability (`createPosQr`/`fetchQr`/`closeQr`
> + `QrCapablePort`, `qr_code.credited` mapping, QR-aware `fetchOrderStatus`) is
> left in place as a **latent** capability (tested in `razorpay-qr.test.ts`) for
> if QR Codes is enabled later — it is NOT wired to the POS tender. Tests:
> `pos-settlement.test.ts`, `razorpay-qr.test.ts`, registry. Original design below
> is retained as rationale.

Status: **planned, not started.** Goal: at POS checkout, the "UPI (online)"
tender shows a **dynamic UPI QR** (on the phone OR the web till); the customer
scans it with any UPI app and pays; the sale **auto-completes** when Razorpay
confirms — no manual "mark paid".

## The good news: ~90% already exists
The Razorpay integration is mature and we reuse it wholesale:
- **Adapter** `providers/razorpay.provider.ts` — raw `fetch`, generic
  `call<T>(method, path, body, {idempotent})` with retry + circuit breaker. A QR
  call is just a new `call('POST', '/payments/qr_codes', …)`.
- **Intent model** `GatewayPayment` (`CREATED→PENDING→CAPTURED|FAILED`) +
  `SettlementTarget {type,id}` + idempotent `initiatePayment`.
- **Webhook pipeline** `POST /payment-gateway/webhook/:provider` — raw-body HMAC
  verify (fail-closed), exactly-once `events.claim`, ownership lookup, then
  `confirm()` = amount-match check + ONE `$transaction` doing
  `updateStatus(CAPTURED)` + `settlementFor(target).onPaid(tx)`. Idempotent.
- **Reconciliation** `reconcileStaleIntents` (cron */15) — polls the gateway and
  self-heals missed webhooks via the same `confirm()` path.
- **Route split** infra (linked accounts, `createTransfers` on-hold, transfer
  reconcile) — present, gated by `ROUTE_SPLIT_ENABLED`.

**What does NOT exist yet:** the `qr_codes` API call, a `qr_code.credited` event
mapping, a `POS` settlement handler, and the POS-side "await payment" UX.

## Flow
```
Web/phone till: tender = "UPI (show QR)"
  └─POST /me/pos/sales/:id/pay-qr──▶ Backend
       lock the cart (Sale → AWAITING_PAYMENT), create GatewayPayment intent
       (target POS:saleId), call Razorpay POST /payments/qr_codes (fixed amount)
       └─▶ returns { qrImageUrl, qrId, amount }
  ◀── render the QR on the phone OR the web (whichever the merchant shows the customer)

Customer scans QR in any UPI app → pays
  Razorpay ──webhook qr_code.credited──▶ /payment-gateway/webhook/razorpay
       verify + dedupe → confirm() → POS settlement onPaid(tx):
         run the normal checkout (invoice + stock + UPI receipt) atomically,
         mode='UPI', modeReference=<razorpay payment id>
       saleBus.publish(pos.checkout) ──▶ both tills flip to "Paid ✓ / receipt"
  (missed webhook? reconcileStaleIntents completes it within ~15 min)
```

## Where we connect — the change list

### 1. Adapter — the one new API call (`razorpay.provider.ts`)
Model on the existing `createSession`:
```ts
// new optional capability, mirroring SplitCapablePort
createPosQr({ amountMinor, intentRef, notes }): Promise<{ qrId: string; imageUrl: string }>
//  → call('POST', '/payments/qr_codes', {
//      type:'upi_qr', usage:'single_use', fixed_amount:true,
//      payment_amount: amountMinor, notes })  → { id:'qr_…', image_url }
fetchQrStatus(qrId): Promise<{ paid: boolean; paymentRef?: string }>
//  → call('GET', `/payments/qr_codes/${qrId}/payments`)   (for reconciliation)
closeQr(qrId)  // POST /payments/qr_codes/:id/close  (on cancel/expiry)
```
Add a `QrCapablePort` + `isQrCapable(provider)` in `ports/` so non-QR providers
are unaffected (same pattern as `SplitCapablePort`).

### 2. Intent — a `POS` settlement target
- Extend `SettlementTarget.type` with `'POS'` (`target.id = Sale.id`).
- New orchestrator path `initiatePosQr({ shopId, saleId, amount, idempotencyKey:'pos-qr:<saleId>' })`
  → create `GatewayPayment` (shopId set), call `createPosQr`, store the QR ref.
  Add `providerQrRef` to `GatewayPayment` (or reuse `providerOrderRef`).

### 3. Sale state — lock while awaiting payment
- New `Sale.status` value **`AWAITING_PAYMENT`** + `Sale.gatewayPaymentId?`.
- `pay-qr` transitions `OPEN → AWAITING_PAYMENT` (cart edits blocked); store the
  intent id. **Why:** the QR amount is fixed at creation — locking prevents the
  cart changing under a pending payment. Cancel → back to `OPEN` + `closeQr`.
- Do **not** confirm the invoice yet — stock/receipt happen only on payment, so
  there's never a confirmed-unpaid invoice or a phantom stock decrement.

### 4. Webhook — map the QR event (`payment-gateway.service.ts`)
- `mapEventType`: add `qr_code.credited → PAID`.
- `parseWebhookEvent`: read `payload.qr_code.entity.id` (and the nested
  `payment.entity`) so the existing ownership lookup resolves our intent.
- Everything downstream (`confirm` → amount check → atomic settle) already works.

### 5. Settlement — a `POS` handler (`settlement/settlement.ts`)
`handlers['POS'].onPaid(intent, tx)`:
- Run the **existing POS checkout money path inside `tx`**: `invoicesService
  .createConfirmedSaleInTx` + `paymentsService.recordReceiptInTx` with
  `mode:'UPI'`, `modeReference:<razorpay payment id>`, idempotencyKey
  `POS:<saleId>:PAY`; set `Sale → CHECKED_OUT, invoiceId`. (This is exactly what
  manual checkout does — the gateway just becomes the trigger.)
- Idempotent (sale.invoiceId anchor) — webhook + reconcile can't double-bill.
- `afterCommit`: `saleBus.publish(shopId, {type:'pos.checkout', saleId, invoiceId})`
  so both tills flip to the receipt.

### 6. Reconciliation — already there
`reconcileStaleIntents` resolves a POS intent via `fetchQrStatus`; a missed
`qr_code.credited` auto-completes the sale within ~15 min. Add an abandon path:
QRs unpaid past N minutes → `closeQr` + Sale back to `OPEN` (or VOIDED).

### 7. Clients — show the QR + await
- **POS checkout UI** (web + Flutter): tender options gain **"UPI (show QR)"**.
  Choosing it calls `pay-qr`, renders `qrImageUrl` large (on whichever device the
  merchant points at the customer), shows "Waiting for payment…", and listens for
  the `pos.checkout` event (already wired) → success screen. A "Cancel" closes the
  QR and unlocks the cart. The QR can be shown on **phone or web** — both have the
  image URL and both already receive `pos.checkout`.
- Manual cash/card tender path is unchanged.

## Settlement — Route to the merchant (DECIDED)
A POS sale is **single-merchant**, so no proportional split — one **Route**
transfer per sale to the shop's `LinkedAccount` (`acc_XXXX`). The marketplace
"hold the payout in Razorpay until the merchant signs up" fallback
(`writeHeldTransferRows` HELD/KYC_GATED) is **NOT used for POS** — in-store money
must settle immediately, so **POS UPI-QR is gated on the shop already having an
active linked account**. No account → the "UPI (show QR)" tender is disabled with
"Connect a payout account first".

### Connect-an-account flow (skip the KYC wizard)
The merchant can attach an existing Razorpay linked account instead of running
the 4-step onboarding:
1. **Enter** their `acc_XXXX`.
2. **Backend verifies** by *fetching* it — `GET /v2/accounts/acc_XXXX` (Accounts
   API, a GET — not a webhook). Reject if it doesn't exist / isn't a linked
   account under our platform / isn't active.
3. **Confirm**: show the fetched details (business/legal name, status, contact,
   payouts-enabled) so the merchant confirms it's theirs.
4. **Store** as the shop's `LinkedAccount` (`providerAccountId = acc_XXXX`,
   `payoutsEnabled` from the fetched status). Done — no PAN/bank re-entry.
- Also subscribe to the **`account.activated`** webhook (push) to flip
  `payoutsEnabled` if the account finishes KYC later.
- Constraint (Razorpay): the id must be a linked account **under our platform**
  account — an arbitrary external Razorpay account can't receive Route transfers
  until it's linked. The GET in step 2 is exactly what enforces this.

> Net for POS checkout: require `shop.linkedAccount.payoutsEnabled === true`
> before offering UPI-QR; the `POS` settlement handler creates one immediate
> transfer to `providerAccountId` in `afterCommit`. Cash/card tender is
> unaffected and needs no linked account.

## Security / correctness (reused)
- Webhook HMAC verify (fail-closed), exactly-once event claim, captured-amount ==
  intent-amount check — all existing in `confirm()`.
- Idempotent across webhook + reconcile + retries (intent status machine +
  `sale.invoiceId` + payment idempotency key).
- No client-trusted amounts: the QR amount is the server-computed sale total;
  the webhook re-verifies the captured amount.
- `pay-qr` gated under the POS area (`invoices:manage`); `shopId` server-derived.

## Phasing
- **P5.0 — Connect account** (prerequisite): `POST /me/linked-account/connect
  {accountId}` → `GET /v2/accounts/:id` verify → return details for confirm →
  `POST …/confirm` stores the `LinkedAccount`; `account.activated` webhook flips
  `payoutsEnabled`. Web + Flutter "Connect Razorpay account" screen (enter id →
  review fetched details → confirm).
- **P5.1 — Backend QR**: adapter `createPosQr`/`fetchQrStatus`/`closeQr` +
  `QrCapablePort`; `qr_code.credited` mapping; `POS` settlement target + handler
  that creates the immediate **Route transfer to the shop's linked account**;
  `pay-qr` endpoint gated on `payoutsEnabled` + `AWAITING_PAYMENT` lock + cancel.
  Backend tests (webhook → sale completes + transfer created; idempotent; amount
  mismatch rejected; gated when no linked account).
- **P5.2 — Till UI**: web + Flutter "UPI (show QR)" tender (render QR, await
  `pos.checkout`, cancel), disabled with a "connect payout account" hint when the
  shop has none. Abandon-sweep closes unpaid QRs and unlocks the cart.

## Risk notes
- Razorpay **QR Codes** must be enabled on the account (and UPI on the MID).
- Test mode: there's no test-mode flag — it's whichever `rzp_test_…` key is set;
  Razorpay's dashboard can simulate a QR payment for webhook testing.
- The `AWAITING_PAYMENT` lock is the main new state-machine edge — cover cancel,
  expiry, and the "paid after cancel" race (the webhook `confirm` is authoritative;
  if it fires after a cancel, reconcile/confirm still completes the sale — decide
  whether a cancelled-then-paid sale auto-completes or refunds).
