# payment-gateway — wiring guide

This module is the **provider-agnostic seam** for online payments (see
`/PAYMENT_GATEWAY_ARCHITECTURE.md`). First vertical slice: **wallet top-up**
(single-tenant, no Route split / on-hold settlement). Other settlement targets
(ORDER / INVOICE / CAUTION) reuse the same core; only their `settlement/`
handler changes.

## What's here

```
payment-gateway/
  ports/            payment-provider.port.ts · repository.port.ts · types.ts
  providers/        razorpay.provider.ts (fetch+crypto, no SDK) · registry.ts (env-gated)
  settlement/       settlement.ts (WALLET wired; ORDER/INVOICE/CAUTION stubbed)
  persistence/      prisma-gateway.repository.ts  (real, Prisma-backed)
  payment-gateway.service.ts   core orchestration (initiate / handleWebhook)
  payment-gateway.controller.ts / .routes.ts
  tracker.ts        structured audit log (console for now)
  index.ts          composition root → exports paymentGatewayService
```

## Step 1 — Prisma models + implement the repo ✅ DONE

> Status: models added, migration `20260620030000_payment_gateway_intents`
> applied, `persistence/prisma-gateway.repository.ts` implemented (real,
> type-checks clean), both tables verified present.
>
> **Drift workaround used (read before the next migration).** `prisma migrate
> dev` here wants to RESET — the DB carries an untracked migration
> (`20260527162713_banner_image_blocks`, another session) plus a raw
> `products.search_vector` index Prisma doesn't model. Reset = data loss, so we
> never run `migrate dev`. The safe additive procedure:
> 1. Edit `schema.prisma`, then `npx prisma generate` (types only, no DB).
> 2. `npx prisma migrate diff --from-config-datasource --to-schema prisma/schema.prisma --script`
>    → copy ONLY your new DDL into `prisma/migrations/<ts>_<name>/migration.sql`
>    (strip unrelated drift lines, e.g. the `ALTER TABLE "products" ... search_vector`).
> 3. `npx prisma db execute --file prisma/migrations/<ts>_<name>/migration.sql`
>    (v7: datasource comes from `prisma.config.ts`; do NOT pass `--schema`).
> 4. `npx prisma migrate resolve --applied <ts>_<name>` to record it in history.
> 5. Verify: `npx prisma migrate status` → "up to date".

The models that were added (for reference):

```prisma
model GatewayPayment {
  id                 Int      @id @default(autoincrement())
  provider           String
  status             String   @default("CREATED") // CREATED|PENDING|CAPTURED|FAILED|REFUNDED
  amount             Decimal  @db.Decimal(12, 2)
  currency           String   @default("INR")
  targetType         String   @map("target_type")  // WALLET|ORDER|INVOICE|CAUTION
  targetId           Int      @map("target_id")
  shopId             Int?     @map("shop_id")
  customerUserId     Int?     @map("customer_user_id")
  providerOrderRef   String?  @map("provider_order_ref")
  providerPaymentRef String?  @map("provider_payment_ref")
  idempotencyKey     String?  @map("idempotency_key")
  createdAt          DateTime @default(now()) @map("created_at")
  updatedAt          DateTime @updatedAt @map("updated_at")

  @@unique([customerUserId, idempotencyKey], name: "gateway_payments_user_idempotency")
  @@index([provider, providerOrderRef])
  @@index([provider, providerPaymentRef])
  @@index([status, targetType])
  @@map("gateway_payments")
}

model GatewayWebhookEvent {
  id          Int       @id @default(autoincrement())
  provider    String
  eventId     String    @map("event_id")
  payload     Json
  processedAt DateTime? @map("processed_at")
  createdAt   DateTime  @default(now()) @map("created_at")

  @@unique([provider, eventId])   // exactly-once dedupe gate
  @@map("gateway_webhook_events")
}
```

## Step 2 — Add a WalletSource for top-ups ✅ DONE
> `'TOPUP'` added to `WalletSource` (wallet.service.ts); settlement constant
> switched from the `'MANUAL'` placeholder to `'TOPUP'`.

## Step 3 — Mount the routers in `infra/http/app.ts` ✅ DONE
> Both mounts are in place: `paymentGatewayPublicRouter` at `/payment-gateway`
> before `express.json` + `requireAuth`; `walletTopUpRouter` at
> `/me/wallet/topup` after `requireAuth`.

```ts
import { walletTopUpRouter, paymentGatewayPublicRouter } from '../../modules/payment-gateway/payment-gateway.routes.js';

// (A) BEFORE app.use(express.json()), and BEFORE requireAuth. Webhook router
//     carries its own express.raw() so the signature sees the exact bytes.
app.use('/payment-gateway', paymentGatewayPublicRouter);

// (B) AFTER app.use(requireAuth), next to the '/me/wallet' mount.
app.use('/me/wallet/topup', walletTopUpRouter);
```

## Step 4 — Env ✅ DOCUMENTED (fill real keys to go live)
> `.env.example` carries the three `RAZORPAY_*` vars (blank = Razorpay stays
> inert). Add real `rzp_test_*` values to your local `.env` to enable it.

```
RAZORPAY_KEY_ID=rzp_test_xxx
RAZORPAY_KEY_SECRET=xxx
RAZORPAY_WEBHOOK_SECRET=xxx          # verifyWebhookSignature fails closed if unset
```

The registry only enables Razorpay when `RAZORPAY_KEY_ID` + `RAZORPAY_KEY_SECRET`
are present. `GET /payment-gateway/providers` reports what's live.

## Step 5 — Razorpay dashboard ⬜ REMAINING (external, needs your account)

Point the webhook at `POST https://<host>/payment-gateway/webhook/razorpay`,
subscribe to at least `payment.captured`, `payment.failed` (add `order.paid`,
`refund.processed` as you extend), set the signing secret to
`RAZORPAY_WEBHOOK_SECRET`. For local testing, tunnel (ngrok) so Razorpay can
reach `localhost:3003`.

## Dependencies

**None.** The adapter uses global `fetch` + node `crypto` (Node 25 / @types/node 22).

## Deferred (next slices — already mapped in the design doc)

- **Atomic settlement**: run `updateStatus` + `settlementFor(...).onPaid` in one
  Prisma tx; thread `tx` into `walletService.credit` (it already accepts one).
- **Reconciliation job** ✅ DONE: `paymentGatewayService.reconcileStaleIntents`
  sweeps `status IN (CREATED,PENDING)` older than the recheck window →
  `provider.fetchOrderStatus` → CAPTURED+settle (missed-webhook heal) or FAILED
  (abandon). Registered in `infra/scheduler.ts` (15-min tick, best-effort
  `tryAcquireJobLock`). Tests in `tests/payment-gateway/service.test.ts`.
- **Route split + on-hold settlement + multi-seller split** (NOT built):
  `SplitCapablePort` is defined and unused; implement on `RazorpayProvider` + a
  `LinkedAccount` model when wiring the ORDER target. See `ROUTE_SPLIT_DESIGN.md`
  and architecture §12.2–12.3.
- **DB-backed tracker**: swap `tracker.ts` console writer for a table writer.
