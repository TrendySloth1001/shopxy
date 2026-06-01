# Marketplace Order Flow — Route + On-Hold Settlement (implementation design)

> ⚠️ **STATUS: DESIGN — NOT BUILT.** None of the models, transfers, or holds
> below exist in code today. The wired `ORDER` settlement (`settlement.ts`) flips
> the order to PAID and collects the full amount into the **platform's own
> Razorpay account** — there is no split and no on-hold settlement yet. Until
> this is built and run against a Razorpay sandbox, do not describe the system as
> holding seller funds, and **do not use the word "escrow" in any product copy,
> UI, or contract** — Razorpay Route `on_hold` is not a licensed escrow; it parks
> funds in Razorpay's regulated balance, with Razorpay as custodian, not us.
> Get compliance/legal signoff before any custody or "escrow" claim ships.
>
> This is the NEXT increment after the core gateway seam
> (`payment-gateway.service.ts`, `providers/razorpay.provider.ts`,
> `settlement/settlement.ts`). It wires the `ORDER` settlement target — today a
> `notWired('ORDER')` stub in `settlement.ts:53` — to Razorpay Route with
> on-hold settlement, per-shop split, release-on-delivery, and reverse-on-return.
>
> Read first: `PAYMENT_GATEWAY_ARCHITECTURE.md` §12.2–12.3 (single→multi split,
> on-hold-settlement delta), `ports/payment-provider.port.ts` (`SplitCapablePort`,
> `TransferRequest`/`TransferResult`, `isSplitCapable`), and
> `providers/razorpay.provider.ts` (`createTransfers`/`releaseTransfer`/
> `reverseTransfer`, already implemented).
>
> **Reference-impl note.** §12 of the architecture doc describes a prior
> production Razorpay Route integration (`payment.service.ts`,
> `payment.webhook.ts`) carrying ~40 post-incident fixes. That `payment/`
> directory is **not present in this checkout** — the canonical porting guidance
> we follow here is §12's reuse map, not the original files. Where this doc says
> "ported from the reference" it means "implements §12's prescribed landing
> spot." If the legacy files resurface, reconcile the linked-account onboarding
> and dispute/replay guards against §6/§5e below.

---

## 0. The shape of a ShopXY marketplace order

One checkout = one `CustomerOrder` (`schema.prisma:1039`) that fans out to N
`PurchaseRequest` children (`schema.prisma:1088`), one per `shopId` the cart
spans. Money facts that drive everything below:

- `CustomerOrder.estimatedTotal` — sum of children at submit (`:1056`).
- `CustomerOrder.couponDiscount` — order-level coupon (`:1060`).
- `CustomerOrder.walletPaid` — wallet-funded slice; the rest is the gateway-
  captured amount (`:1063`). **The captured payment is `estimatedTotal −
  couponDiscount − walletPaid`** — only THAT is splittable via Route.
- `PurchaseRequest.estimatedTotal` (`:1135`) — the per-shop slice we key the
  split on (per §12.2).
- `PurchaseRequest.shopId` → `Shop` (`:1098`). The seller's payout destination
  is the linked account on that `Shop`.
- Returns are per-child: `ReturnRequest.requestId → PurchaseRequest`
  (`:1216`), refunds run through `returns.service.ts:refund` (`:430`).
- The settlement target id for `ORDER` is the `CustomerOrder.id`
  (`ports/types.ts:32` `SettlementTarget`).

The gateway intent (`GatewayPayment`, arch §7) settles **once** against the
parent order; the split fans that one capture out to N held transfers, one per
child `PurchaseRequest`.

---

## 1. New Prisma models

Added to `backend/prisma/schema.prisma`. Money is `Decimal(12,2)`, snake_case
`@map`, matching every existing model.

### 1.1 `LinkedAccount` — per-shop Razorpay payout destination

```prisma
/// One payout destination per Shop (Razorpay Route "linked account").
/// Created via the merchant KYC onboarding flow (§6). A Shop with no row,
/// or a row whose payoutsEnabled is false, CANNOT receive a held transfer —
/// the ORDER settlement handler gates on this (§2, edge KYC-not-activated).
model LinkedAccount {
  id             Int     @id @default(autoincrement())
  shopId         Int     @unique @map("shop_id")
  shop           Shop    @relation(fields: [shopId], references: [id], onDelete: Cascade)
  provider       String  @default("RAZORPAY")
  /// Razorpay linked-account id (acc_XXXX) — the `account` in TransferRequest.
  providerAccountId String? @map("provider_account_id")
  /// KYC lifecycle mirrored from account.* webhooks (§5):
  /// CREATED → UNDER_REVIEW → ACTIVATED | NEEDS_CLARIFICATION | SUSPENDED.
  kycStatus      String  @default("CREATED") @map("kyc_status")
  /// True only once Razorpay confirms the account can be settled to. The
  /// settlement handler refuses to create a transfer otherwise.
  payoutsEnabled Boolean @default(false) @map("payouts_enabled")
  /// Contact/business snapshot captured at onboarding (audit + re-KYC).
  email          String?
  contactName    String? @map("contact_name")
  businessType   String? @map("business_type")
  createdAt      DateTime @default(now()) @map("created_at")
  updatedAt      DateTime @updatedAt @map("updated_at")

  transfers GatewayTransfer[]

  @@index([provider, providerAccountId])
  @@map("linked_accounts")
}
```

Plus the inverse on `Shop` (`schema.prisma:1908`-block): `linkedAccount
LinkedAccount?`.

### 1.2 `GatewayTransfer` — one held split per child PurchaseRequest

```prisma
/// One Route transfer per (GatewayPayment, PurchaseRequest). Tracks the
/// on-hold lifecycle independently of the parent intent so a single order can
/// have some children released and others reversed.
model GatewayTransfer {
  id                Int     @id @default(autoincrement())
  /// Parent gateway intent (the captured payment we split). FK kept loose
  /// (Int, not relation) to match how GatewayPayment is referenced elsewhere;
  /// upgrade to a relation when GatewayPayment lands as a real model.
  gatewayPaymentId  Int     @map("gateway_payment_id")
  /// The child this transfer settles. One transfer per PurchaseRequest.
  purchaseRequestId Int     @map("purchase_request_id")
  purchaseRequest   PurchaseRequest @relation(fields: [purchaseRequestId], references: [id], onDelete: Cascade)
  /// Destination linked account (denormalised acct id for audit even if the
  /// LinkedAccount row is later edited).
  linkedAccountId   Int?    @map("linked_account_id")
  linkedAccount     LinkedAccount? @relation(fields: [linkedAccountId], references: [id], onDelete: SetNull)
  providerAccountId String  @map("provider_account_id")

  amount            Decimal @db.Decimal(12, 2)
  /// Razorpay transfer id (trf_XXXX). Null only in the brief window between
  /// row insert and the createTransfers call returning (§2 ordering).
  providerTransferRef String? @map("provider_transfer_ref")
  /// HELD | RELEASED | REVERSED | FAILED. String (not enum) so a future
  /// PARTIALLY_REVERSED can be added without a migration, matching the
  /// ReturnRequest.status convention.
  status            String  @default("HELD")
  /// on_hold_until echoed back; null = indefinite hold released by our flow.
  holdUntil         DateTime? @map("hold_until")
  releasedAt        DateTime? @map("released_at")
  reversedAt        DateTime? @map("reversed_at")
  /// Amount reversed so far (partial returns). status flips to REVERSED only
  /// when reversedAmount == amount.
  reversedAmount    Decimal @default(0) @map("reversed_amount") @db.Decimal(12, 2)
  failureReason     String? @map("failure_reason")
  createdAt         DateTime @default(now()) @map("created_at")
  updatedAt         DateTime @updatedAt @map("updated_at")

  @@unique([gatewayPaymentId, purchaseRequestId], name: "gateway_transfers_payment_request")
  @@index([status, holdUntil])
  @@index([purchaseRequestId])
  @@index([providerTransferRef])
  @@map("gateway_transfers")
}
```

The `@@unique([gatewayPaymentId, purchaseRequestId])` is the idempotency gate:
a redelivered capture webhook re-runs the split handler but can't mint duplicate
transfers (see §2, step 4).

---

## 2. ORDER settlement handler — create held transfers on capture

Replaces `settlement.ts:53` (`ORDER: notWired('ORDER')`). New file
`settlement/order.settlement.ts`, registered in the `handlers` map. It runs
**inside the same `prisma.$transaction`** the core opens in
`payment-gateway.service.ts:268` (`onPaid(settled, tx)`), so the intent flip to
`CAPTURED` and the transfer-row writes commit atomically.

```ts
const orderSettlement: SettlementHandler = {
  async onPaid(intent, tx) {
    // 1. Load children + each shop's linked account.
    const children = await tx.purchaseRequest.findMany({
      where: { customerOrderId: intent.target.id },
      select: { id: true, shopId: true, estimatedTotal: true,
                shop: { select: { linkedAccount: true } } },
      orderBy: { id: 'asc' },   // deterministic allocation order (§7 rounding)
    });
    // 2. Compute the captured-splittable base = sum(children.estimatedTotal)
    //    minus coupon, scaled so children sum EXACTLY to intent.amount (§7).
    const shares = allocateProportional(
      children.map(c => Number(c.estimatedTotal)),
      intent.amount,              // already net of wallet/coupon (intent.amount IS the captured)
    );
    // 3. KYC gate (§5e edge): a child whose shop lacks an ACTIVATED, payouts-
    //    enabled linked account is NOT transferred now — its row is recorded
    //    FAILED with reason KYC_NOT_ACTIVATED and swept by reconciliation /
    //    retried when account.activated arrives. The other children still settle.
    // 4. Insert GatewayTransfer rows (status HELD, providerTransferRef null)
    //    via createMany skipDuplicates on the (paymentId, requestId) unique —
    //    a redelivered webhook is a no-op here.
    // 5. AFTER the tx commits, call provider.createTransfers(...) with
    //    on_hold:true and on_hold_until = returns-window close (§3, §7).
  },
};
```

Key decisions, each grounded:

- **Split key = `PurchaseRequest.estimatedTotal`** (per §12.2 / `schema.prisma:1135`).
- **`intent.amount` is the captured rupee amount** (`ports/types.ts:50`,
  domain-unit). The handler converts to paise only at the provider edge via
  `helpers.toMinorUnits` (`helpers.ts:12`), which carries the prior G23 float
  fix — never multiply by 100 inline.
- **`createTransfers` must run AFTER capture and BEFORE any refund** — Razorpay
  rejects transfers on a payment with an initiated refund, and the adapter
  already raises a domain-clear error for it
  (`razorpay.provider.ts:338-354`). The core orders capture→settlement→(later)
  refund, so this holds; the edge catalog (§7) covers the race.
- **Transfer creation runs OUTSIDE the Serializable tx** (step 5), exactly the
  caveat in §12.5. The DB rows are written first (HELD, ref null) inside the tx;
  the provider call patches `providerTransferRef` after. If the process dies
  between commit and the provider call, reconciliation finds HELD rows with a
  null `providerTransferRef` and replays `createTransfers` (idempotent on the
  unique key). **Never** call `razorpay.transfers.*` raw — always through the
  adapter (§12.5 minor fix).
- **`onHoldUntil`** is the per-shop returns-window close: `confirmedAt +
  Shop.returnWindowDays` (`schema.prisma:1853`). Clamped to the adapter's
  `ON_HOLD_UNTIL_MIN/MAX` bounds (`razorpay.provider.ts:37-38`); see §7.

---

## 3. RELEASE — wired to delivery + returns-window close

A held transfer is released when the seller has earned the money: the order is
delivered AND the return window has elapsed (or the shop has
`returnsEnabled:false`). Two release paths, both calling
`provider.releaseTransfer(transferRef)` then flipping
`GatewayTransfer.status = RELEASED, releasedAt = now()`:

1. **Auto (primary): scheduled `releaseDueTransfers` job.** Selects
   `GatewayTransfer WHERE status='HELD' AND holdUntil <= now()` (the
   `@@index([status, holdUntil])` serves this). Razorpay also auto-releases at
   `on_hold_until`; our PATCH is the belt to its suspenders so our row state
   never lags the provider. Idempotent: releasing an already-released transfer
   is a no-op we swallow.
2. **Event-driven (optional fast path): on `DELIVERED`.** When the merchant
   posts a `PurchaseRequestEvent` of type `DELIVERED`
   (`schema.prisma:1204`, via `POST /orders/:id/events`), if the shop has
   `returnsEnabled:false` we may release immediately. If returns are enabled we
   do NOT release early — the money must stay on hold through the window so an
   in-hold return can reverse cleanly (§4).

Release is **only ever** initiated for transfers whose owning child has no open
return (`ReturnRequest.status IN REQUESTED/APPROVED/PICKED_UP/RECEIVED` against
`requestId`). The release job joins to `return_requests` and skips children with
an open return, deferring them until the return resolves.

---

## 4. REVERSE — on an in-hold return

A return that lands while the transfer is still `HELD` (the common case, since
the hold spans the return window) reverses funds back to the platform before
they ever reach the seller. Hook point: `returns.service.ts:refund` (`:430`),
which today only credits the customer wallet. We extend it (or wrap it) so that
inside the same transaction that flips `ReturnRequest.status='REFUNDED'`:

```ts
// Find the child's transfer for this order's capture.
const transfer = await tx.gatewayTransfer.findFirst({
  where: { purchaseRequestId: row.requestId, status: { in: ['HELD','RELEASED'] } },
});
if (transfer?.providerTransferRef) {
  const reverseMinor = toMinorUnits(returnRefundAmount);   // partial-aware
  // OUTSIDE-tx provider call queued post-commit (same pattern as create):
  await provider.reverseTransfer(transfer.providerTransferRef, reverseMinor);
  // bump reversedAmount; flip to REVERSED iff reversedAmount == amount.
}
```

- **Partial return → partial reversal.** `ReturnRequestItem.refundAmount`
  (`schema.prisma:1282`) sums to a refund smaller than the child's transfer.
  Pass that amount to `reverseTransfer` (the adapter forwards it as a partial
  reversal — `razorpay.provider.ts:365-372`). Track cumulative
  `reversedAmount`; only flip `status=REVERSED` when it equals `amount`,
  otherwise leave `HELD` (partial). Multiple partials are allowed.
- **HELD vs RELEASED.** If the transfer is still `HELD`, reversal is clean
  (money never left the hold). If already `RELEASED` (window elapsed, then a late
  return), Razorpay still allows a reversal but it pulls from the linked
  account's balance — which may now be empty (§7 reversal-balance failure).
- **Refund ordering.** Because Razorpay forbids creating transfers on a
  refunded payment, the customer-facing wallet refund (the `WalletEntry` in
  `returns.service.ts:519`) and the Route reversal are independent: the wallet
  credit makes the buyer whole; the reversal claws the money back from the
  seller. We do NOT issue a gateway `refund()` to the original method in WALLET
  refund mode — only the reversal + wallet credit. A gateway refund to source is
  only for `Shop.refundMode='ORIGINAL'` (`schema.prisma:1859`) and, when used,
  must run AFTER all transfers exist (which they do by capture time).

---

## 5. Webhook handling — `transfer.*` and `account.*`

Extends the core `handleWebhook` (`payment-gateway.service.ts:160`) and the
adapter's `parseWebhookEvent` (`razorpay.provider.ts:183`). New normalized event
types are added to `GatewayEventType` (`ports/types.ts:67`):
`TRANSFER_PROCESSED | TRANSFER_FAILED | TRANSFER_REVERSED | ACCOUNT_UPDATED`.

The adapter's `mapEventType` (`razorpay.provider.ts:41`) gains:

| Razorpay event | Normalized | Action |
|---|---|---|
| `transfer.processed` | `TRANSFER_PROCESSED` | Mark `GatewayTransfer` RELEASED/settled (reconciles our PATCH). |
| `transfer.failed` | `TRANSFER_FAILED` | Mark transfer `FAILED`, set `failureReason`, alert reconciliation. |
| `transfer.reversed` | `TRANSFER_REVERSED` | Confirm reversal; bump `reversedAmount`, flip REVERSED when full. |
| `account.activated` | `ACCOUNT_UPDATED` | `LinkedAccount.payoutsEnabled=true, kycStatus=ACTIVATED`; retry any `FAILED`/`KYC_NOT_ACTIVATED` transfers for that shop. |
| `account.needs_clarification` / `account.suspended` | `ACCOUNT_UPDATED` | Update `kycStatus`, set `payoutsEnabled=false`. |

Crucial reuses of the existing webhook discipline:

- **a. Ownership-first + ack-and-ignore.** `transfer.*`/`account.*` events on a
  **shared** Razorpay account that aren't ours are acked-and-ignored exactly
  like §8 of the arch doc and `payment-gateway.service.ts:188-201`. Resolution:
  `transfer.*` → look up `GatewayTransfer.providerTransferRef`; `account.*` →
  `LinkedAccount.providerAccountId`. No match ⇒ 200, no-op (never 500, which
  auto-disables the webhook).
- **b. Exactly-once.** Reuse `GatewayWebhookEvent (provider, eventId)` claim
  (`repository.port.ts:54`, `payment-gateway.service.ts:205`). The
  `x-razorpay-event-id` header is the dedupe key
  (`razorpay.provider.ts:208-211`).
- **c. Settle-before-mark-processed** (`payment-gateway.service.ts:217-229`) —
  if the transfer-state write throws, `processedAt` stays null for the audit
  trail and reconciliation retries.
- **d. Raw body.** These ride the SAME `express.raw()` webhook route (arch §8.1);
  no new endpoint, no new HMAC path.
- **e. Dispute / chargeback (§12 "DISPUTE branch").** `payment.dispute.*`
  events: on a lost dispute the platform is debited, so any HELD transfer for
  that payment must be **reversed** (claw back the seller before they withdraw)
  and any RELEASED transfer flagged for manual recovery. The replay guard is
  essential — disputes redeliver; the eventId claim covers it.

---

## 6. Per-merchant Razorpay KYC onboarding (ports §12.1 "highest-value piece")

New `linked-accounts` sub-feature. §12.1 says: re-target the reference's
`createLinkedAccount` onboarding, mapping its `coaching` row → our
`LinkedAccount` table. Surface:

- **Port extension.** Add to `SplitCapablePort` (or a sibling
  `OnboardingCapablePort` in `ports/payment-provider.port.ts`):
  ```ts
  createLinkedAccount(p: {
    email: string; phone: string; legalBusinessName: string;
    businessType: string; shopId: number;
  }): Promise<{ providerAccountId: string; kycStatus: string }>;
  fetchAccountStatus(providerAccountId: string): Promise<{ kycStatus: string; payoutsEnabled: boolean }>;
  ```
- **Adapter.** `razorpay.provider.ts` implements these against Razorpay's
  `/v2/accounts` (+ product-config / stakeholder) endpoints, through the same
  `this.call(...)` wrapper (`razorpay.provider.ts:94`) so error classification
  (401 config / 402 balance / 429 backoff) is shared. No raw SDK call.
- **Service + routes.** `linked-accounts.service.ts` + merchant routes
  (`POST /shops/:shopId/linked-account` to start KYC, `GET` to poll status).
  Tenant-scoped via the existing `resolveShop`/`requireRole` middleware (same as
  every merchant route). One `LinkedAccount` per shop (`@@unique shopId`).
- **State source of truth** is the `account.*` webhook (§5), not the create
  response — `kycStatus`/`payoutsEnabled` only become trustworthy on
  `account.activated`. Onboarding-created accounts start `CREATED /
  payoutsEnabled:false`.
- **Carry-over fix (§12.5):** route every onboarding call through the wrapper;
  don't copy the reference's per-coaching ledger aggregates.

---

## 7. Edge-case catalog (each tied to code that enforces or must enforce it)

1. **Split BEFORE refund ordering.** Razorpay rejects `createTransfers` on a
   payment with an initiated refund; the adapter raises a clear domain error
   (`razorpay.provider.ts:338-354`). Enforcement: the ORDER handler runs at
   capture; gateway refunds (ORIGINAL mode only) are sequenced strictly after.
   In WALLET refund mode we never call gateway `refund()`, so no ordering
   conflict — we reverse instead (§4).
2. **Partial refund on a multi-transfer order.** Return is per-child
   (`ReturnRequest.requestId`), refund per-item (`ReturnRequestItem.refundAmount`,
   `schema.prisma:1282`). Reverse ONLY that child's transfer for ONLY the
   refunded amount; siblings' transfers are untouched. Track `reversedAmount`;
   flip `REVERSED` only at full.
3. **Reversal-balance failure.** If a transfer is already `RELEASED` and settled
   (or the seller withdrew), reversal can fail with insufficient balance.
   `this.call` maps Razorpay 402 to a non-retryable 402
   (`razorpay.provider.ts:121-129`); §12.1 says surface for **manual
   reconciliation**. We set `GatewayTransfer.status=FAILED`,
   `failureReason='REVERSAL_INSUFFICIENT_BALANCE'`, still credit the customer
   wallet (buyer is made whole), and open a recovery task. Negative seller
   balance is then carried as platform receivable.
4. **KYC-not-activated gating.** A child whose shop has no `LinkedAccount`, or
   `payoutsEnabled:false`, is NOT transferred at capture — its row is `FAILED`
   `KYC_NOT_ACTIVATED`; siblings still settle. `account.activated` (§5) retries
   it. The customer's payment still captures (they get goods); only the
   seller's payout waits on their KYC.
5. **Rounding so children sum to the captured total.** Proportional allocation
   of `intent.amount` across `PurchaseRequest.estimatedTotal` shares can leave a
   1-paise residue. `allocateProportional` floors each share in paise, then
   assigns the leftover paise to children in a deterministic order
   (`orderBy id asc`, §2) so `Σ child = intent.amount` EXACTLY. Convert at the
   edge with `helpers.toMinorUnits` (`helpers.ts:12`, G23 float-safe), never
   `* 100` inline.
6. **Hold-timestamp bounds.** `on_hold_until` must fall within
   `ON_HOLD_UNTIL_MIN (946684800)`–`ON_HOLD_UNTIL_MAX (4765046400)`
   (`razorpay.provider.ts:37-38`); the adapter validates and rejects out-of-band
   values with a 400 (`:297-306`). `holdUntil = confirmedAt +
   Shop.returnWindowDays`; if `returnWindowDays=0` (return-forever,
   `schema.prisma:1853`) we OMIT `on_hold_until` for an indefinite hold released
   explicitly by our flow (§3) — never send 0 or a past timestamp. Also clamp:
   if the computed window exceeds MAX, hold indefinitely.
7. **Minimum transfer amount.** Each share must be ≥ ₹1 (100 paise,
   `MIN_TRANSFER_PAISE`, `razorpay.provider.ts:36`); the adapter rejects a batch
   naming the offending index (`:288-316`). A sub-₹1 child slice (e.g. a ₹0.50
   line after coupon proration) is folded into the largest sibling's share
   during allocation so no transfer is created below the floor.
8. **Negative linked-account balance.** Result of reversing already-withdrawn
   funds (edge 3) or a lost dispute (edge 9). Razorpay carries it as a negative
   balance recovered from the seller's next settlements; we mirror it as a
   `failureReason` flag + recovery task and do NOT block the customer outcome.
9. **Dispute-lost reversal.** `payment.dispute.lost` → reverse HELD transfers
   for that payment, flag RELEASED ones for manual recovery (§5e). Replay guard
   via the eventId claim is mandatory — disputes redeliver.
10. **PPI / PA regulatory note.** Razorpay Route settles seller→seller; the
    platform is a facilitator, not a holder of customer funds, which keeps us
    clear of needing a Payment Aggregator (PA) licence for the split itself.
    BUT the wallet (`WalletEntry`, `schema.prisma:1317`) — customer money held
    and spendable across merchants — is a **PPI** concern under RBI (arch §11
    open question). On-hold settlement via `on_hold` parks funds in Razorpay's
    balance, not ours, so it doesn't add PPI exposure. Flag for compliance before enabling
    customer-funded wallet top-ups that feed Route splits; gateway→wallet
    top-up (`settlement.ts:21`) is the piece to review, not the order split.

---

## 8. Migration steps (documented drift workaround — never `migrate dev`)

The repo's shadow DB is broken (`apply_invitations_notifications` won't apply to
an empty DB; PHASES.md:107). Additive changes ship manually. For
`linked_accounts` + `gateway_transfers`:

```bash
# 1. Edit prisma/schema.prisma — add LinkedAccount, GatewayTransfer, and the
#    Shop.linkedAccount + PurchaseRequest.gatewayTransfers inverse relations.

# 2. Generate the SQL by DIFFING the live DB against the edited schema
#    (do NOT run migrate dev — it would try the broken shadow DB):
mkdir -p prisma/migrations/20260530120000_route_split_linked_accounts
npx prisma migrate diff \
  --from-url "$DATABASE_URL" \
  --to-schema-datamodel prisma/schema.prisma \
  --script > prisma/migrations/20260530120000_route_split_linked_accounts/migration.sql

# 3. Review the SQL — it must be purely additive (CREATE TABLE linked_accounts,
#    gateway_transfers; CREATE INDEX/UNIQUE; ADD COLUMN nothing-NOT-NULL-without-
#    default). No drops, no destructive ALTERs.

# 4. Apply it directly:
npx prisma db execute \
  --file prisma/migrations/20260530120000_route_split_linked_accounts/migration.sql

# 5. Mark it applied so history stays consistent (no shadow-DB replay):
npx prisma migrate resolve \
  --applied 20260530120000_route_split_linked_accounts

# 6. Regenerate the client:
npx prisma generate
```

This is the same `migrate diff → db execute → migrate resolve` pattern used for
`20260619010000_caution_requests_and_forfeit` and `20260619050000_quotations`.
After it, swap the stub `persistence/prisma-gateway.repository.ts` and the
`notWired('ORDER')` handler to the real implementations described above, and add
the `transfer.*`/`account.*` branches to the adapter + core. Type-check with
`npx tsc --noEmit` before wiring routes.
