# POS UPI-QR payments (P5) — design

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

## The one decision you need to make — settlement target
A POS sale is **single-merchant**, so no proportional split is needed — but the
money must reach the merchant:

- **A. Collect to platform (simplest, works today).** QR money lands in the
  platform Razorpay account; the platform remits to the merchant out of band
  (or via existing payouts). No per-merchant KYC needed to start. Good for a
  pilot; **not** how a real multi-merchant POS should run long-term.
- **B. Route straight to the merchant (correct, needs onboarding).** Create the
  QR/transfer against the **merchant's LinkedAccount** (the payout-onboarding
  flow already exists, gated by `ROUTE_SPLIT_ENABLED` + `payoutsEnabled`). One
  immediate transfer per sale (no on-hold split needed — single shop). Requires
  the merchant to have completed KYC.

Recommendation: **A for the first cut** (ship + validate the QR UX), with the
`POS` settlement handler written so flipping to **B** is just "create a transfer
to the shop's linked account in `afterCommit` when `payoutsEnabled`" — the Route
plumbing for that already exists.

## Security / correctness (reused)
- Webhook HMAC verify (fail-closed), exactly-once event claim, captured-amount ==
  intent-amount check — all existing in `confirm()`.
- Idempotent across webhook + reconcile + retries (intent status machine +
  `sale.invoiceId` + payment idempotency key).
- No client-trusted amounts: the QR amount is the server-computed sale total;
  the webhook re-verifies the captured amount.
- `pay-qr` gated under the POS area (`invoices:manage`); `shopId` server-derived.

## Phasing
- **P5.1** adapter `createPosQr`/`fetchQrStatus`/`closeQr` + `QrCapablePort`;
  `qr_code.credited` mapping; `POS` settlement target + handler; `pay-qr`
  endpoint + `AWAITING_PAYMENT` lock + cancel. Backend tests (webhook → sale
  completes; idempotent; amount mismatch rejected). Settlement option **A**.
- **P5.2** web + Flutter "UPI (show QR)" tender UI (render QR, await `pos.checkout`,
  cancel). Abandon-sweep for unpaid QRs.
- **P5.3** settlement option **B** (Route transfer to the merchant's linked
  account) behind the existing flag.

## Risk notes
- Razorpay **QR Codes** must be enabled on the account (and UPI on the MID).
- Test mode: there's no test-mode flag — it's whichever `rzp_test_…` key is set;
  Razorpay's dashboard can simulate a QR payment for webhook testing.
- The `AWAITING_PAYMENT` lock is the main new state-machine edge — cover cancel,
  expiry, and the "paid after cancel" race (the webhook `confirm` is authoritative;
  if it fires after a cancel, reconcile/confirm still completes the sale — decide
  whether a cancelled-then-paid sale auto-completes or refunds).
