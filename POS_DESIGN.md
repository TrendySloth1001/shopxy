# ShopXY POS + Live Catalog — System Design

Status: **proposal / for review**. Scope: in-store point-of-sale built on the
existing scan prototype. This document is the contract we build against.

## 1. Decisions (locked with product)

| Axis | Decision | Consequence |
|------|----------|-------------|
| **Till topology** | **Both devices share one live cart** — phone *and* web can scan and check out the same sale | Cart state must be **server-authoritative** (not on either client) |
| **Payment** | **Bill + manual tender** (cash/UPI/card mode recorded), v1 | Reuse `invoices` + `payments` + `ledger`; no gateway yet |
| **Connectivity** | **Resilient-online** | Idempotent ops + client outbox + reconnect rehydrate; **no** offline catalog |
| **Scale** | **Small now, clean seams** | Postgres = truth (already multi-instance safe); realtime fan-out swappable to Redis later |

## 2. Guiding principle — the server owns the cart

The single most important decision: **the open sale (cart) is a row in Postgres,
and the server is the only thing that mutates it.** Clients never hold the
authoritative cart; they render a projection and send *intents*.

This one choice satisfies three requirements at once:

- **Shared cart** — both devices read/write the same DB row, so they're always
  looking at the same sale. No client-to-client sync, no CRDT.
- **Resilient-online** — a client crash/disconnect loses nothing; on reconnect it
  re-fetches the sale and resumes. The WS is an accelerator, not the store.
- **Scalable** — Postgres is already consistent across N backend instances. Only
  the *"tell the other device something changed"* notification is instance-local
  today, and that's the one seam we make swappable (§9).

> Money rule (non-negotiable): **the client never sends prices or totals.** It
> sends `productId + quantity` (and tender mode). The server prices every line
> from the catalog and computes all tax/totals. This is both a correctness and a
> security control.

## 3. Architecture overview

```
   ┌─────────────┐         intents (scan/qty/checkout)        ┌─────────────┐
   │ Flutter app │ ───────────  WS (live) / REST  ──────────▶ │             │
   │  (till A)   │ ◀───────────  sale state events  ───────── │   Backend   │
   └─────────────┘                                            │  (Express)  │
   ┌─────────────┐                                            │             │
   │  Web till   │ ◀──────────────────────────────────────▶  │  pos.service│
   │  (till B)   │     same sale room (keyed by saleId)       └──────┬──────┘
   └─────────────┘                                                   │
                                                          ┌──────────┴───────────┐
                                                          │  Postgres (truth)     │
                                                          │  Sale / SaleLine      │
                                                          │  Invoice / Payment    │
                                                          │  StockTransaction     │
                                                          └───────────────────────┘
        realtime fan-out: in-memory hub now ──(seam)──▶ Redis pub/sub / PG NOTIFY later
```

- **Cart lifecycle**: a `Sale` is `OPEN` while scanning, `CHECKED_OUT` once it
  becomes a confirmed `Invoice`, or `VOIDED` if abandoned/cancelled.
- **Realtime**: extends the existing scan-console WS hub
  (`modules/scan-console`) — same ticket auth, same room concept, but rooms are
  keyed by **`saleId`** (a device joins a sale) in addition to shop presence.
- **Checkout**: converts the `Sale` into a **confirmed `Invoice` + `Payment`**
  via the existing, proven money path (`invoices.service` → `ledger.service` →
  `payments.service`), which already does `SELECT … FOR UPDATE`, `Serializable`
  isolation, oversell prevention, and idempotency.

## 4. Data model

New, lightweight, **mutable** cart tables. Deliberately *not* reusing a DRAFT
invoice as the cart, because `createInvoice` mints an FY-scoped invoice number at
creation (`nextInvoiceNo`) — using drafts as carts would burn gaps in the legal
`INV/25-26/NNNNN` sequence on every abandoned cart. The cart mints an invoice
number **only at checkout**.

```prisma
model Sale {                       // the open cart — high-churn, mutable
  id           Int       @id @default(autoincrement())
  shopId       Int       @map("shop_id")
  status       String    @default("OPEN")   // OPEN | CHECKED_OUT | VOIDED
  // Optimistic-concurrency cursor: every mutation bumps this; events carry it.
  version      Int       @default(0)
  // Optional walk-in identity (kept off the legal doc until checkout).
  partyId      Int?      @map("party_id")
  customerName String?
  customerPhone String?
  headerDiscount Decimal @default(0) @db.Decimal(12, 2)
  note         String?
  // Set once on successful checkout — the idempotency anchor (§7).
  invoiceId    Int?      @unique @map("invoice_id")
  openedById   Int?      @map("opened_by_id")
  createdAt    DateTime  @default(now())
  updatedAt    DateTime  @updatedAt
  lines        SaleLine[]
  @@index([shopId, status])
}

model SaleLine {
  id           Int      @id @default(autoincrement())
  saleId       Int      @map("sale_id")
  productId    Int      @map("product_id")
  // Priced from catalog at add-time, but re-validated at checkout (truth = catalog).
  quantity     Decimal  @db.Decimal(12, 3)
  unitPrice    Decimal  @db.Decimal(12, 2)
  lineDiscount Decimal  @default(0) @db.Decimal(12, 2)
  addedById    Int?     @map("added_by_id")
  createdAt    DateTime @default(now())
  sale         Sale     @relation(fields: [saleId], references: [id], onDelete: Cascade)
  @@unique([saleId, productId])   // one row per product; re-scan bumps qty
  @@index([saleId])
}
```

Reused as-is at checkout (no schema change):
`Invoice` + `InvoiceItem` (the bill, with full GST split), `Payment` (tender),
`StockTransaction` (stock OUT via `ledger.service`). All three already carry
`idempotencyKey` / idempotent posting.

## 5. Realtime cart sync

Server-authoritative with optimistic clients:

1. A device opens/joins a sale → server returns the **full sale snapshot**
   (`{ sale, lines, totals, version }`).
2. Device sends an **intent** (`addScan {code}`, `setQty {productId, qty}`,
   `removeLine`, `setDiscount`, `checkout`). Carried over WS, with a REST mirror
   for the resilient path.
3. Server mutates Postgres in a short transaction, **bumps `sale.version`**, and
   **broadcasts the resulting delta** (`line.upserted`, `line.removed`,
   `totals`, each stamped with the new `version`) to the sale room.
4. Clients apply the delta if `version` is contiguous; if they detect a gap
   (missed a message), they **re-fetch the snapshot** (cheap self-heal).

Events on the sale room (extends `ScanConsoleEvent`):
`sale.snapshot`, `line.upserted`, `line.removed`, `sale.totals`,
`sale.checkout` (terminal), `presence` (who's on this till), `ack {opId}`.

### Concurrency (two cashiers, one cart)
- **Scan / qty-increment is additive** → commutative, always safe (re-scan adds
  qty). This is the common case and needs no locking beyond the row write.
- **Edit / remove / set-absolute-qty** uses **optimistic concurrency**: the
  intent may carry the `version` it was based on; if stale, server applies
  last-write-wins but the rejected client re-syncs from the broadcast. A single
  `Sale` row write is the serialization point.
- Per-sale writes are serialized by a row-level update on `Sale` (bump version)
  inside the same tx as the line change.

## 6. "Listing new products" (unknown scan → quick add)

When a scanned code resolves to nothing (`resolveScan` returns null), the server
emits `scan.unknown {code}`. The till offers **Quick add**:

- Minimal form: name, selling price, tax % (defaults from a shop setting),
  optional barcode = the scanned code.
- Server calls existing `productsService.createProduct` (gated by
  `products:manage`), then auto-adds the new product to the open sale.
- Full catalog fields (HSN, cost, images) can be completed later from Products —
  the quick-add only needs what billing requires.

## 7. Checkout — the money path (reuse, atomic, idempotent)

`POST /me/pos/sales/:id/checkout` with body `{ tender: { mode, modeReference? },
customer? }` and an **`Idempotency-Key`** header.

Flow (one logical, idempotent operation):

```
1. Load Sale (status=OPEN) for shopId.  If sale.invoiceId already set → return it
   (idempotent replay: a retried checkout never double-bills or double-decrements).
2. Re-price every line from the live catalog (truth), build InvoiceItemInput[].
3. invoicesService.createInvoice({ type:'SALE', documentType: <reg? TAX_INVOICE
   : BILL_OF_SUPPLY>, partyId, items, discount: headerDiscount, confirm: true })
     → DRAFT created, then CONFIRMED in-tx → ledger.post() decrements stock with
       SELECT…FOR UPDATE + Serializable + idempotencyKey `INVOICE:{id}:CONFIRM`
       (oversell impossible; insufficient stock fails the whole checkout cleanly).
4. paymentsService.createPayment({ type:'RECEIPT', mode, amount: invoice.total,
       invoiceId, partyId, idempotencyKey: `POS:{saleId}:PAY` }).
5. Mark Sale CHECKED_OUT, set sale.invoiceId; broadcast `sale.checkout` to the room.
6. Return { invoice, payment } → till prints/﻿shares the receipt (existing PDF path).
```

- **Atomicity**: invoice-confirm (incl. stock) is already one `Serializable`
  transaction. Checkout wraps invoice + payment so a sale yields exactly one
  confirmed invoice and its receipt; if payment recording fails post-confirm, the
  invoice exists as **confirmed-unpaid** (shows as outstanding) and is safely
  re-payable — no money or stock corruption. (Stretch: run both under one shared
  `tx` via the services' `tx`-accepting internals for full all-or-nothing.)
- **Idempotency anchor**: `sale.invoiceId` is the top-level guard; `Idempotency-Key`
  + the per-row idempotency keys (`INVOICE:{id}:CONFIRM`, `POS:{saleId}:PAY`)
  make every layer retry-safe. This is what makes "resilient-online" correct.

## 8. Resilient-online mechanics

- **Client outbox**: each intent gets a client `opId`. Intents queue locally and
  flush over WS/REST; the server **dedupes by `opId`** and `ack`s. On reconnect,
  the client replays un-acked ops then re-fetches the snapshot.
- **No offline catalog**: scanning/pricing requires the server (catalog is the
  truth). A drop pauses *new* scans but never loses the in-progress sale.
- **Checkout through a drop**: safe to retry — idempotent on `sale.invoiceId` +
  `Idempotency-Key`. The till shows "finalising…" and reconciles on reconnect.
- **Crash recovery**: sale lives in Postgres; reopening the till rehydrates it.

## 9. Tools & scaling seams

Stay on the **existing stack** — no new datastore, no framework churn:

| Concern | Now (small) | Seam → scale |
|---------|-------------|--------------|
| Cart state | **Postgres** `Sale`/`SaleLine` | already correct across N instances |
| Money path | `invoices`/`ledger`/`payments` (Serializable, row-locked, idempotent) | unchanged; add read replicas if read-heavy |
| Realtime fan-out | in-memory hub (`scan-console`) | **`PubSub` interface** → swap to **Redis pub/sub** (we already run `ioredis`) or **Postgres `LISTEN/NOTIFY`** (zero extra infra) for multi-instance |
| WS transport | raw `ws` + ticket auth (built) | keep; behind a load balancer enable sticky sessions or move to Redis-backed presence |
| Idempotency | existing `idempotencyKey` columns | unchanged |

We introduce **one abstraction**: a `SaleBus` interface (`publish(saleId, event)`
/ `subscribe`). Today it's the in-memory hub; the multi-instance upgrade is a
single adapter swap — **no change to pos.service or clients.** Recommended scale
adapter: Redis pub/sub (already a dependency); PG `LISTEN/NOTIFY` is the
no-new-infra alternative.

> Deliberately **not** adopted now: Socket.IO (raw `ws` + ticket already works and
> is lighter), a separate cart store/Redis-as-truth (Postgres is correct and we
> avoid a consistency split), CRDTs/offline sync (out of scope per "resilient-
> online"), a queue for checkout (TPS doesn't warrant it at this scale).

## 10. Security

- **Server-priced** lines & totals; client amounts are never trusted (§2).
- **Auth**: JWT for REST; the existing **one-time ticket** for WS upgrade. Every
  sale/line/checkout op derives `shopId` from the token — never from the client.
- **Permissions** (reuse the area/permission model): scanning/cart edit →
  `products:view`; quick-add → `products:manage`; checkout (bill + tender) →
  `invoices:manage` + `payments:manage`. A view-only cashier can't finalise.
- **Multi-tenant isolation**: every query scoped by `shopId`; the WS sale room is
  validated to belong to the caller's shop on join.
- **Idempotency** on every write to prevent double-charge/double-decrement.
- **Audit**: `openedById`, `addedById`, invoice `confirmedById`, payment
  `createdById`, plus the immutable `StockTransaction` ledger.
- **Rate-limit** scan/checkout endpoints (reuse the existing limiter pattern).

## 11. Module layout

```
backend/src/modules/pos/
  pos.service.ts      # open/join sale, add-scan, set-qty, remove, discount, checkout
  pos.realtime.ts     # sale rooms + SaleBus (extends scan-console hub)
  pos.controller.ts   # REST mirror of intents + checkout (Idempotency-Key)
  pos.routes.ts       # /me/pos/* mounted via mountMerchant (area: 'invoices')
  pos.bus.ts          # SaleBus interface + in-memory adapter (Redis adapter later)
```
Reuses `invoices.service`, `payments.service`, `ledger.service`,
`products.service`, `sequences`. Web + Flutter reuse the WS client already built
for scan-console (add sale-room messages).

## 12. Phased delivery

- **P0 — Cart + checkout (no realtime):** `Sale`/`SaleLine` migration,
  `pos.service` (add/qty/remove/discount), checkout reusing invoice+payment+ledger,
  REST endpoints, idempotency. Backend tests for the money path. *Shippable as a
  single-device POS.*
- **P1 — Shared live cart:** sale rooms over the existing WS, server-authoritative
  deltas + version, optimistic clients, presence. Both devices on one cart.
- **P2 — Quick-add products:** unknown-scan → create + auto-add.
- **P3 — Resilient-online:** client outbox + opId dedupe + reconnect rehydrate;
  receipt PDF/share.
- **P4 — Scale seam:** extract `SaleBus`, add Redis pub/sub adapter; multi-instance test.
- **P5 (future) — Integrated payments:** gateway-collected UPI/card on the same checkout.

## 13. Resolved decisions

- **Held sales** — **yes, lightweight.** Multiple `OPEN` sales per shop are
  allowed; the till can resume any open sale. No extra schema (the model already
  supports it).
- **Price/qty edits** — quantity + **discount** editable by any cart editor
  (`products:view`); **unit-price override requires `invoices:manage`**. Cashiers
  cannot silently reprice.
- **Checkout atomicity** — **single shared `prisma.$transaction`.** Invoice
  (create + confirm + stock ledger) and payment commit all-or-nothing. Achieved by
  extracting the pure invoice computation so `pos.checkout` reuses it inside one
  transaction (no behaviour change to existing `createInvoice`).

## 14. Out of scope (v1) / later

- **Returns/refunds at POS** — the existing returns/credit-note path covers it.
- **Receipt hardware** (thermal printer) — v1 uses the existing PDF/share.
- **Integrated gateway payments** — P5 (future).
```
