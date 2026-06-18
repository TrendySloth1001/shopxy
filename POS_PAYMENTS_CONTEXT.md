# Session context — POS + Payments (handoff / pre-compaction)

Snapshot of everything built in this session + the live blocker, so work resumes
after a conversation compaction. All work below is **committed and merged to
`main`** unless stated. Repo: `/Users/nick/shopxy` (single git repo: `backend/`
Express+Prisma+Postgres, `merchant-web/` Next.js :3010, `customer-web/` :3009,
`frontend/` Flutter merchant, `customer/` Flutter customer).

## Where we are right now — the LIVE BLOCKER (active task)
Merchant pasted Razorpay linked account **`acc_SVOGhSVZjzfBq7`** (email
nkumawat8956@gmail.com). Razorpay **dashboard shows it "● Activated"**, but our
system shows "not activated" and POS UPI stays gated. I queried Razorpay directly
(read-only) in **both test and live** keys:
```
GET /v2/accounts/acc_SVOGhSVZjzfBq7   → { type:"route", status:"created" }   (NOT "activated")
GET /v2/accounts/acc_SVOGhSVZjzfBq7/products → "no Route matched"             (no route product)
```
So per the **v2 Accounts API**, the account is `created` with no `route` product
→ genuinely can't receive Route transfers. The dashboard "Activated" pill is the
account holder's own activation, not the platform-Route status. Our gating
(`payoutsEnabled` derived from `mapProviderKyc(status)`) is therefore correct.

**User's claim:** payouts worked perfectly in their **`tutorix`** project.
**NEXT TASK:** inspect the tutorix project's Razorpay Route implementation
(account create/onboard, product config, transfer code, what status/flow it
relies on) and compare to ShopXY — figure out why theirs settles and ours
gates. (Find tutorix dir: likely `/Users/nick/tutorix` or a sibling of shopxy.)

`backend/.env` currently holds **LIVE** Razorpay keys (`rzp_live_…`). A read-only
`GET /v2/accounts/:id` is safe; do NOT attempt real transfers without explicit OK.

## POS feature (built this session, all on `main`)
Server-authoritative cart, **driven ENTIRELY over WebSocket** (no REST for
cart/checkout). See `POS_DESIGN.md`.
- **Backend** `backend/src/modules/pos/`:
  - `pos.service.ts` — **functional module, no classes**, typed **DTOs** (no
    any/unknown): `SaleSnapshot`, `SaleLineDto`, `SaleTotalsDto`, `PosError`,
    `UnknownScan`, `CheckoutResultDto{invoiceId,invoiceNo,total,paymentRef,mode,replayed}`.
    Funcs: openSale (reuses empty OPEN sale), snapshot, listOpenSales,
    sweepStaleSales, addScan, addProduct, setQty, setLineDiscount, setUnitPrice,
    removeLine, setHeaderDiscount, quickAddProduct, voidSale, checkout.
  - `pos.ws.ts` — functional WS **command router**: `{t:'cmd',reqId,op,saleId?,…}`
    → `{t:'res',reqId,ok,data|error}`. Ops: open/snapshot/listOpen/scan/addItem/
    setQty/setLineDiscount/setUnitPrice/removeLine/setHeaderDiscount/quickAdd/
    checkout/void. zod-validated; quickAdd gated on `products:manage`.
  - `pos.bus.ts` — `SaleBus` (in-memory now, Redis pub/sub adapter for
    multi-instance; falls back in-memory). Broadcasts version-nudge events
    `pos.sale|pos.checkout|pos.void` (NO cart/PII on the wire).
  - `pos.controller.ts`/`pos.routes.ts` — only `POST /me/pos/ticket` remains
    (mints the WS ticket carrying shopId+userId+role+permissions). Mounted
    `/me/pos` under the **invoices** area.
  - Checkout = single Serializable tx reusing the proven money path:
    `invoicesService.createConfirmedSaleInTx` (+ stock via `ledgerService.post`,
    oversell-safe) + `paymentsService.recordReceiptInTx`; idempotent on
    `sale.invoiceId` (FOR UPDATE re-check); walk-in → system "Walk-in Customer"
    party. Tests: `backend/tests/pos/pos.test.ts` (money path) + `pos-ws.test.ts`
    (dispatch). Migrations: `sales`/`sale_lines` (20260620170000), `sale_ops`
    dedupe (20260620180000).
- **WS transport** rides the **scan-console** socket (`modules/scan-console/
  scan-console.service.ts`): shop rooms + one-time ticket + `WsAuthCtx` +
  `registerWsCommandHandler` (POS registers its handler in `server.ts` — keeps
  deps one-way, no cycle). Path `/ws/scan-console`.
- **Clients**: `merchant-web/src/features/pos/` (usePosSale = WS command client,
  reqId-correlated, outbox, reconnect-resume; view + quick-add) and
  `frontend/lib/features/pos/` (PosSaleClient = WS command client; pos_page.dart
  scanner+cart+checkout). Both use `requestPosTicket`→`/api/pos/ticket` or
  `/me/pos/ticket`, then `wss://<host>/ws/scan-console?ticket=…&role=console`.

## Scan-console + scan-intake
- **Scan console** (live phone→web product scanning) shipped earlier: backend WS
  hub, merchant-web `features/scan-console`, Flutter `features/scan_console`.
- **Scan-to-add (catalog intake)** = DESIGN ONLY, parked: `SCAN_INTAKE_DESIGN.md`
  (phone barcode gun → product-add form on web; not built).

## Payments / Razorpay Route (the area under active investigation)
- Gateway: **Razorpay**, ports/adapters, raw fetch. `backend/src/modules/
  payment-gateway/` — `providers/razorpay.provider.ts` (generic `call()`,
  `createSession`/orders, `createLinkedAccount` v2, `fetchAccountStatus`,
  **added** `fetchAccount` for connect-by-id), webhook pipeline (HMAC verify,
  exactly-once, `confirm()` amount-check + atomic settlement), `reconcileStaleIntents`
  cron, Route split infra gated by `ROUTE_SPLIT_ENABLED` (default off).
- `mapProviderKyc(status)` (`kyc-status.ts`): activated/funds_released→ACTIVATED+payouts;
  under_review/needs_clarification/suspended/funds_held→not; **default→CREATED**.
- **Linked accounts** `backend/src/modules/linked-accounts/`:
  - `startOnboarding` (the API KYC wizard create — requests the `route` product),
    `reconcilePendingKyc`, `getStatus`, `refreshStatus` (re-polls, throttled 30s,
    skips if already payoutsEnabled).
  - **Added this session**: `verifyConnect(accountId)` (GET fetch, no write) +
    `confirmConnect(shopId, accountId)` (store; rejects ALREADY_LINKED). Routes
    `POST /linked-account/connect` + `/connect/confirm` (payouts area).
  - `LinkedAccount` model: one-per-shop, `providerAccountId(acc_…)`, `kycStatus`,
    `payoutsEnabled`, email/contactName/businessType.
  - Account `account.activated/.under_review/…` webhook → `ACCOUNT_UPDATED` →
    `settlement/webhook-handlers.ts handleAccountUpdated` flips payoutsEnabled.
- **POS UPI-QR** = DESIGN ONLY, NOT built: `POS_UPI_QR_DESIGN.md` (P5). Plan:
  Razorpay QR Codes API (`createPosQr`), map `qr_code.credited` webhook, a `POS`
  settlement target, gate on the shop's linked account, settle via Route transfer.
- **Connect-existing-account UI (built this session)**:
  - merchant-web: `features/payouts/connect-account-card.tsx` + `onboarding-wizard.tsx`
    (4-step KYC) + `api.ts`; rendered on `/dashboard/payouts`. BFF:
    `/api/linked-account` (POST create), `/connect`, `/connect/confirm`, `/payouts`.
  - Flutter: `features/shop/.../connect_linked_account_page.dart` + the existing
    4-step wizard `shop_payouts_page.dart` (enriched to show full account details
    + "Refresh from Razorpay" re-poll). `LinkedAccountStatus` model gained
    email/contactName/businessType. Status label fixed: CREATED → "Not activated
    yet — finish KYC" (was mislabelled "Under review").

## Design docs in repo root
`POS_DESIGN.md`, `POS_UPI_QR_DESIGN.md`, `SCAN_INTAKE_DESIGN.md` (this session);
plus pre-existing `ACCOUNTING_AUDIT.md`, `CODE_REVIEW.md`.

## Verify commands
- backend: `cd backend && npx tsc --noEmit` ; `npx vitest run tests/pos tests/linked-accounts tests/permissions`
- merchant-web: `cd merchant-web && npx eslint src && npx tsc --noEmit` (do NOT `npm run build` while `npm run dev` runs — corrupts `.next`)
- Flutter: `cd frontend && flutter analyze lib/features/pos`
- Pre-existing: backend vitest has ~44 env failures on a clean baseline (merchant-route 403s) — stash-and-compare, don't attribute to POS.

## Conventions / gotchas
- Money path: every write idempotent; shopId server-derived; reuse invoices/
  ledger/payments — don't reinvent billing.
- POS code: **functional, no classes; real DTOs, no any/unknown** (user pref).
- New migrations get today's date which sorts BEFORE committed 20260620xxxx ones
  → rename dir to a timestamp after the latest; hand-write SQL to dodge the
  generated `search_vector` column drift.
- Multiple Claude sessions run on this repo; surprise edits may be another session.
