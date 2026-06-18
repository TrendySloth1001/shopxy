# Scan-to-add (catalog intake) — design

Status: **planned, not started.** Parked for later. Feature: the merchant uses
the phone as a barcode gun; for each scan a product-add form appears on the
**web** (typing on a keyboard beats a phone). Same phone→WebSocket→web topology
as POS / scan-console, so it reuses that plumbing wholesale.

## Decisions (locked with product)
- **Phone scans → form appears on the web** (phone = scanner peripheral).
- **Barcode-only prefill** (v1) — no external barcode DB yet.
- **Continuous stocking loop** — scan, scan, scan; cards queue on the web.
- **Streamlined quick-add form** — name, selling price, tax %, opening stock
  (barcode pre-filled, read-only); "More details" expands to the full editor.

## Flow
```
[ Phone — Flutter ]  scan ──POST /me/scan-intake/scan──▶ Backend
   "sent · NEW / already in catalog · N web form(s) open"   │ lookup in shop
                                                            │ broadcast to web room
[ Web — merchant-web ] ◀── WS  intake.scan {code, exists, product?} ──┘
   NEW code  → quick-add form card (barcode prefilled) → fill → Save → product created
   EXISTING  → "Already in catalog" card → Open editor / quick restock
```

## What's new (most of it is reuse)

### Backend — new `modules/scan-intake/` (small)
- `POST /me/scan-intake/scan {code, opId?}` — resolve product in shop; broadcast
  `{type:'intake.scan', code, exists, product?}` to the shop's web room via the
  existing `scanConsoleHub.publishRaw`; return `{exists, product?, consoles}` to
  the phone. `opId` dedupe (reuse the `SaleOp`-style guard) so a re-fire doesn't
  double-card.
- `POST /me/scan-intake/product {code, name, sellingPrice, costPrice?, taxPercent?, openingStock?}`
  — minimal catalog create with opening stock posted via the ledger (extract the
  logic from POS `quickAddProduct`, minus the cart-add). Returns the product.
- Mount `/me/scan-intake` under the **`products`** area (`products:manage` to
  create catalogue). **WS ticket: reuse `/me/scan-console/ticket`** (already
  `products` area) — no new ticket endpoint.

### Web — `features/scan-intake/` + `/dashboard/scan-intake`
- WS console (reuse scan-console ticket + `wsBase` + the connection/reconnect
  hook). Handles only `intake.scan` events (ignores `pos.*`/`scan` — they share
  the room harmlessly).
- A **queue of cards**: NEW → inline streamlined form (auto-focus name); Save →
  `POST /api/scan-intake/product` → "Added ✓". EXISTING → product summary +
  "Open editor" (`/dashboard/products/[id]`) + quick restock.
- Dedup by code (one card per pending code). Presence badge ("scanner connected").
- BFF: `/api/scan-intake/product` (create) + reuse `/api/scan-console/ticket`.

### Flutter — `features/scan_intake/` "Scan to add" screen
- Continuous `mobile_scanner` (debounced, like the POS page). Each scan →
  `POST /me/scan-intake/scan` → ack chip "New — fill it on the web" / "Already in
  catalog" + "N web form(s) open" (from `consoles`) + an "added today" tally.
  Drawer entry gated by `products:view`.

## Security / correctness
- `shopId` server-derived; every query shop-scoped; create gated `products:manage`.
- Server validates the create payload (zod) and dedupes `barcode`/`sku` (globally
  unique → "code already exists" is also the EXISTING path).
- `opId` dedupe on scan; events carry no PII (code + product name/sku only).
- Single instance now; the same Redis pub/sub seam (`publishRaw`/bus) applies later.

## Phasing
- **P1** backend intake (scan + minimal create) + web console/form + Flutter
  screen — end-to-end loop. Tests for minimal-create + dedupe.
- **P2** existing → inline quick restock; "More details" → full editor.
- **P3 (optional)** external barcode-DB lookup to pre-fill name/brand, manual fallback.

## Why it's cheap
Reused as-is: WS endpoint + ticket, shop rooms + `publishRaw`, presence, the
Flutter scanner + connection client, the web WS hook, `productsService
.createProduct` + ledger opening-stock. New: one small backend module, one web
page, one Flutter screen.

> Note: kept as a **separate module** from scan-console because its scan
> semantics are the opposite — surface *unknown* codes to the web, vs the
> console's *matched* scans.
