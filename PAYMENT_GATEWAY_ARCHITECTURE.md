# Payment Gateway Architecture

> Status: **Design**. Author target: integrate Razorpay first, with a
> provider-agnostic seam so additional gateways (Stripe, PhonePe, Cashfree, …) can be
> added later without touching existing gateways or domain logic.

## 1. Goals & constraints

1. **Adding/removing a gateway must not affect any other gateway.** A second provider
   is a new adapter file + one registry line — nothing else changes.
2. **Domain money-logic is single-sourced and reused** by every gateway via public
   helper/service functions (no Razorpay-specific copy in four places).
3. Fits the existing codebase conventions: `module/<name>.{routes,controller,service}.ts`,
   Prisma + Postgres, `Decimal(12,2)` money, snake_case `@map`, `requireEnv`/`envOr`
   config, Serializable transactions, and the client-supplied idempotency-key pattern
   already used in `payments.service.ts`.
4. Reuses the seams already designed into the schema:
   - `CautionRequest.channel / provider / providerRef` — built for exactly this.
   - `PlatformBankOffer` discount "stubbed until a real gateway lands".
   - `CustomerOrder.walletPaid` + `WalletEntry(source=CHECKOUT)` — wallet/gateway split.

## 2. Core principle — Ports & Adapters (Hexagonal)

The failure mode of multi-gateway code is letting provider-shaped data (paise,
`razorpay_payment_id`, provider webhook JSON, provider status strings) leak into the
domain. Then gateway #2 means rewriting everything that touched it.

The fix: **one stable port interface** every gateway implements. The domain only ever
sees provider-neutral DTOs. All provider knowledge is quarantined inside its adapter.

```
                    ┌─────────────────────────────────────┐
   HTTP / webhook   │   paymentGatewayService (CORE)       │
   ───────────────► │   provider-agnostic orchestration    │
                    │   initiate / handleWebhook /          │
                    │   reconcile / refund                  │
                    └───────┬───────────────────┬───────────┘
                            │                   │
              resolves via  │                   │ on confirmed payment
              registry      ▼                   ▼
                    ┌───────────────┐   ┌──────────────────────┐
                    │ PaymentGateway│   │  SettlementTarget     │
                    │  Port         │   │  WALLET|ORDER|        │
                    └───────────────┘   │  INVOICE|CAUTION      │
                      ▲   ▲   ▲          └──────────────────────┘
              ┌───────┘   │   └───────┐    reuses existing
              │           │           │    walletService,
        Razorpay      Stripe…    PhonePe…   paymentsService, caution
```

- **Left half answers "doesn't affect other gateways"** — the adapter layer. Isolated.
- **Right half answers "reusable public helper functions"** — core + settlement + helpers.

## 3. Module layout

```
src/modules/payment-gateway/
  payment-gateway.routes.ts        # POST /initiate, POST /webhook/:provider, GET /:id
  payment-gateway.controller.ts
  payment-gateway.service.ts       # CORE — provider-agnostic orchestration
  ports/
    payment-provider.port.ts       # interface every gateway implements
    types.ts                       # normalized DTOs (GatewaySession, NormalizedEvent…)
    repository.port.ts             # persistence behind an interface
  providers/
    razorpay.provider.ts           # adapter #1 — ONLY Razorpay knowledge lives here
    registry.ts                    # provider string → adapter, env-gated
  settlement/
    settlement.ts                  # targetType → handler; bridges to existing domain
  helpers.ts                       # pure reusable helpers (minor-units, hmac, status map)
```

Keep this **separate from the existing `payments` module** — that one is the merchant's
manual receipt/payment ledger. This new module is *online collection*. They meet only at
settlement, where a gateway-collected invoice payment writes a normal `Payment` row
through the existing `paymentsService` — reuse, not duplication.

## 4. The port — what every gateway must satisfy

```ts
export interface PaymentGatewayPort {
  readonly name: string;                       // 'RAZORPAY'
  createSession(p: CreateSessionParams): Promise<GatewaySession>;
  buildClientParams(p): Record<string, unknown>;
  verifyHandshake(p: HandshakeParams): boolean;          // UX only
  verifyWebhookSignature(rawBody: Buffer, headers): boolean;
  parseWebhookEvent(rawBody: Buffer, headers): NormalizedEvent;
  fetchPaymentStatus(providerPaymentRef: string): Promise<NormalizedStatus>;
  refund(p: RefundParams): Promise<NormalizedRefund>;
}
```

All return **normalized DTOs** so the core never sees provider strings. Marketplace
split + on-hold settlement is the optional `SplitCapablePort`
(createTransfers/release/reverse) — a gateway that can't split just doesn't implement
it; the core checks `isSplitCapable()`. (NB: "on-hold settlement" = Razorpay Route
`on_hold`, funds held in Razorpay's regulated balance — not a licensed escrow, and
never described as "escrow" in product copy. See `ROUTE_SPLIT_DESIGN.md`.)

## 5. The registry — env-gated; enabling a gateway is config, not code

```ts
const providers = new Map();
if (process.env.RAZORPAY_KEY_ID) providers.set('RAZORPAY', new RazorpayProvider());
// if (process.env.STRIPE_SECRET_KEY) providers.set('STRIPE', new StripeProvider());
```

## 6. The settlement bridge — the "reusable public helpers"

On a confirmed payment, the core dispatches by `targetType` to a handler calling
*existing* domain code:

```ts
const handlers = {
  WALLET:  (intent) => walletService.credit({ source: 'TOPUP', idempotencyKey: `gw:${intent.id}`, ... }),
  INVOICE: (intent) => paymentsService.createPayment({ ...mapIntentToReceipt(intent) }), // REUSE
  CAUTION: (intent) => approveCautionFromGateway(intent),  // reuses CautionRequest seam
  ORDER:   (intent) => customerOrderService.markPaid(intent.targetId),
};
```

### Settlement target details

| Target | Initiated from | On webhook `PAID` |
|--------|----------------|-------------------|
| **WALLET** | Customer wallet top-up | `WalletEntry(source=TOPUP)` + denormed balance, idempotency-keyed |
| **ORDER** | Customer checkout | Flip `CustomerOrder` to paid (+ Route split per shop if used) |
| **INVOICE** | Merchant pay-link | Write a `Payment` receipt via `paymentsService.createPayment` |
| **CAUTION** | Party caution request | Drive the existing approval path → `CautionTxn(DEPOSIT)` |

## 7. New Prisma models

```prisma
model GatewayPayment {                 // the payment intent / attempt
  id Int @id @default(autoincrement())
  provider String
  status String @default("CREATED")     // CREATED|PENDING|CAPTURED|FAILED|REFUNDED
  amount Decimal @db.Decimal(12,2)
  currency String @default("INR")
  targetType String @map("target_type") // WALLET|ORDER|INVOICE|CAUTION
  targetId Int @map("target_id")
  shopId Int? @map("shop_id")
  customerUserId Int? @map("customer_user_id")
  providerOrderRef String? @map("provider_order_ref")
  providerPaymentRef String? @map("provider_payment_ref")
  idempotencyKey String? @map("idempotency_key")
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")
  @@unique([customerUserId, idempotencyKey], name: "gateway_payments_user_idempotency")
  @@index([provider, providerOrderRef])
  @@index([status, targetType])
  @@map("gateway_payments")
}

model GatewayWebhookEvent {            // append-only dedupe + audit
  id Int @id @default(autoincrement())
  provider String
  eventId String @map("event_id")
  payload Json
  processedAt DateTime? @map("processed_at")
  createdAt DateTime @default(now()) @map("created_at")
  @@unique([provider, eventId])        // exactly-once
  @@map("gateway_webhook_events")
}
```

## 8. Security & correctness gotchas

1. **Raw body for webhooks.** Global `express.json()` at `app.ts:140` would break HMAC
   verification — mount the webhook route with `express.raw()` BEFORE the JSON parser.
2. **Never trust the client success callback.** The webhook is the source of truth.
3. **Idempotent webhooks.** `GatewayWebhookEvent (provider, eventId)` unique + Serializable.
4. **Amount/currency re-check** before settling.
5. **Money in minor units at the boundary** (`helpers.toMinorUnits`).
6. **Reconciliation job** for missed webhooks (ioredis lock).
7. **Tenant scoping** on initiate.
8. **Shared-account webhooks**: one Razorpay account = one webhook stream. If the account
   is shared with another app, this endpoint receives the other app's events too — they
   have no intent here and must be **acked-and-ignored** (never 500-retried, which would
   get the webhook auto-disabled). Tag orders with an `app` note for dashboard filtering.

## 9. Adding gateway #2 — the checklist (proof of isolation)

1. (optional) `npm i <provider-sdk>` — or HMAC + REST via fetch.
2. Add `providers/<name>.provider.ts` implementing `PaymentGatewayPort`.
3. Add one line to `registry.ts` gated on its env var.
4. Add its `*_WEBHOOK_SECRET` etc. to env.

Zero edits to: the core, settlement, existing adapters, domain services, or the schema.

## 10. Dependencies

The Razorpay adapter uses global `fetch` + node `crypto` — **no new dependency**. Swap to
the official `razorpay` SDK later if preferred; only the adapter changes.

## 11. Open questions

- Refund initiation surface: merchant button, auto on order cancel, or both?
- Capture-on-success (recommended start) vs authorize-then-capture.
- Discount math owner for `PlatformBankOffer` / coupons at initiate time.
- Wallet PPI / aggregator compliance (RBI) if customer funds are held & spent across merchants.

---

## 12. Reuse map — porting the prior Razorpay implementation

A prior, production-hardened Razorpay Route integration exists (the `payment/` directory:
`payment.service.ts`, `payment.webhook.ts`, `payment.reconciliation.ts`,
`payment-tracker.ts`, etc.), carrying ~40 documented post-incident fixes. It is **NOT
provider-agnostic and NOT domain-agnostic** — lift the *logic* into the layers below, not
the files.

### 12.1 Where each piece lands

| Prior code | Lands in | Action |
|---|---|---|
| sig verify (L455-474) | `razorpay.provider.verifyHandshake` | **Port** — timing-safe compare is correct. |
| webhook raw-body + HMAC (L23-61) | routes + `verifyWebhookSignature` | **Port** — solves the `express.json` gotcha. |
| `createOrder` / `createMultiOrder` | core `initiatePayment` + `createSession` | **Adapt** — strip fee/coaching; keep idempotency. |
| `_processPayment` capture→record | core `handleWebhook` → settlement | **Re-map** domain writes to settlement handlers. |
| `_processPaymentWithRetry` (40001) | core retry wrapper | **Keep** — key correctness property. |
| replay/age/amount cross-verify | core webhook guards | **Keep**. |
| Route transfer (L2046-2123) | `SplitCapablePort` + ORDER settlement | **Adapt** — single→multi (12.2), on-hold settlement (12.3). |
| `createLinkedAccount` onboarding | new `linked-accounts` + adapter | **Port — highest-value piece.** Re-target `coaching` row → `LinkedAccount` table. |
| `initiateOnlineRefund` (DB-first) | core `refund` + adapter `refund` | **Keep the pattern**. |
| `refund.*` / `payment.failed` webhooks | core `handleWebhook` branches | **Re-map** to settlement. |
| dispute/chargeback (L463-641) | core DISPUTE branch | **Adapt** — replay guard essential. |
| `transfer.*` / `account.*` webhooks | ORDER settlement / linked-accounts | **Keep**. |
| `payment.reconciliation.ts` | scheduled reconciliation job | **Keep structure** — stuck orders/transfers/refunds, RBI SLA. |
| `PaymentTracker` | `tracker.ts` | **Near drop-in** — rename scope enum. |
| `toPaise`/`toRupees` | `helpers.ts` | **Keep**. |
| `calcConvenienceFee` + modes | (deferred) fee module | **Defer** — only if customer pays gateway fees. |
| `inferLegacyRefundPaymentMap`, subscription recovery | — | **Drop** — legacy data ShopXY won't have. |

### 12.2 Delta: single-seller → marketplace split

Prior code does one transfer to one linked account per payment. ShopXY's `CustomerOrder`
fans out to N `PurchaseRequest` children across N shops → N transfers to N linked
accounts. Reuse the proportional-allocation logic but key the split on per-shop
`PurchaseRequest.estimatedTotal`.

### 12.3 Delta: on-hold settlement / hold (net-new)

Prior code transfers immediately on capture — no `on_hold`. To add on-hold
settlement (Razorpay Route holds the funds in its own regulated balance — this is
NOT a licensed escrow and is never called "escrow" in product copy): create
transfers with `on_hold: true` (+ `on_hold_until`); track `GatewayTransfer.status =
HELD|RELEASED|REVERSED`; add a release path triggered by delivery / `returns`-window
close; in-hold returns = `reverseTransfer`.

### 12.4 Net-new for ShopXY

1. Port/adapter + registry. 2. `LinkedAccount` model on `Shop` (none today).
3. On-hold settlement. 4. Multi-seller split. 5. `GatewayWebhookEvent (provider,
eventId)` unique dedupe.

### 12.5 Minor fixes to carry over

- One raw `razorpay.transfers.reverse` bypasses the `rzpCall` wrapper — always go through
  the adapter.
- Transfer creation runs outside the Serializable tx — recovery depends on reconciliation
  actually running.
- Don't copy the per-coaching ledger aggregates verbatim.
