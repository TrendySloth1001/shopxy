# Backend Module Map

45 modules under `backend/src/modules/`. Each module is a `*.service.ts` (business logic)
plus its controller/routes. The diagram below shows **actual service-to-service
dependencies** (derived from imports of `*.service.js`), grouped by domain.

`A --> B` means **A's service imports B's service**. Modules with no arrows are
self-contained (they only touch Prisma + shared helpers).

```mermaid
flowchart LR
  %% ---------- Domains ----------
  subgraph Identity["🔐 Identity & Access"]
    auth
    invitations
    team
    me
    notifications
    contactlog["contact-change-log"]
  end

  subgraph Catalog["📦 Catalog & Inventory"]
    products
    categories
    collections
    search
    stock
    stockadj["stock-adjustments"]
    customFields
    reviews
  end

  subgraph Discovery["🏬 Storefront & Discovery"]
    home
    banners
    carousels
    brandspotlight["brand-spotlight"]
    flashsales["flash-sales"]
    trending
    promotions
    coupons
    marketplace
    events
  end

  subgraph Commerce["🧾 Commerce & Orders"]
    cart
    invoices
    challans
    quotations
    purchasereq["purchase-requests"]
    returns
    ledger
  end

  subgraph Parties["🤝 Parties"]
    parties
    vendors
    addresses
  end

  subgraph Money["💰 Money & Payments"]
    payments
    paygw["payment-gateway"]
    wallet
    caution
    linkedacct["linked-accounts"]
    bankoffers["platform-bank-offers"]
  end

  subgraph Ops["📊 Ops & Admin"]
    dashboard
    analytics
    reports
    shop
    upload
  end

  %% ---------- Dependencies (import-derived) ----------
  auth --> invitations
  auth --> notifications
  auth --> team
  team --> invitations

  me --> caution
  me --> quotations

  challans --> invoices
  challans --> ledger
  invoices --> ledger
  quotations --> invoices
  stock --> invoices
  stockadj --> ledger
  products --> ledger
  products --> search
  returns --> ledger
  returns --> notifications
  returns --> wallet

  purchasereq --> coupons
  purchasereq --> flashsales
  purchasereq --> invoices
  purchasereq --> notifications
  purchasereq --> wallet

  home --> banners
  home --> brandspotlight
  home --> categories
  home --> collections
  home --> flashsales
  home --> promotions
  home --> trending

  marketplace --> bankoffers

  parties --> caution
  parties --> contactlog
  parties --> payments
  vendors --> contactlog
  vendors --> payments
```

## Notes

- **`ledger` is the money hub** — `invoices`, `challans`, `products`, `returns`, and
  `stock-adjustments` all post into it. Treat it as the source of truth for balances.
- **`invoices` is the order hub** — `quotations`, `challans`, `stock`, and
  `purchase-requests` all converge on it (accept-a-quote / fulfil-a-challan →
  confirmed invoice).
- **`home`** is a pure read-aggregator (fans out to every storefront-surface module);
  it produces no writes.
- **`purchase-requests`** and **`returns`** are the heaviest fan-out writers — they
  touch coupons/flash-sales, invoices, wallet, and notifications.
- Standalone modules (no service-to-service edges): `addresses`, `analytics`,
  `cart`, `carousels`, `categories`, `customFields`, `dashboard`, `events`,
  `linked-accounts`, `payment-gateway`, `reports`, `reviews`, `shop`, `upload`,
  plus all the leaf storefront modules.
