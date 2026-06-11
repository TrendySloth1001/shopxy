# PENDING.md — customer-web

Deferred wiring and known stubs. **Read this before implementing a new feature**
— when you build something here, check whether it unblocks an item below and
wire it up. **When you stub, defer, or simplify something, add a row here** with
where it lives and what triggers finishing it.

Format: `[ ]` open · `[x]` done. "Trigger" = the feature whose arrival means
this should be revisited.

## Deferred wiring (stubbed — connect when the trigger lands)

- [x] **Home feed built (`/`).** Full marketplace home — port of the Flutter
  customer `HomePage`. Lives in `src/features/home/`: `types`, `mapper`,
  `composer` (the 36-step block cycle), `api`, `tracking`, BFF routes
  (`/api/home/feed`, `/feed/page`, `/personalized`, `/events`), and
  `components/*` (top bar, search bar, category rail, trust strip, 7-template
  hero banners, flash deals, brand spotlight, collection banner, recently
  viewed, footer, + all ~24 feed blocks). Endless scroll + impression tracking
  wired. The old token gallery moved to `/tokens`.
- [x] **Home destination pages are stubs.** Product tiles/banners/category pucks
  link to `/product/[id]`, `/search?q=`, `/shop/[slug]`, `/category/[slug]`,
  `/collection/[slug]`, `/banner/[id]` — **none of these pages exist yet** so
  taps 404. Build them (PDP first) and the home already links in. Helpers:
  `productHref` (product-tile), `searchHref` (product-carousel), `slideHref`
  (hero-slide).
  **DONE (cross-link wiring pass):** `productHref` updated to canonical `/p/${id}`,
  banner href updated to `/banners/${id}`, category rail updated to `/c/${slug}`
  (falls back to `/categories`), flash-deals "See all" → `/deals`, brand-spotlight
  "View all" → `/spotlights`. Remaining stubs: `/collection/[slug]`, `/deals`,
  `/banners/[id]` pages not yet built — taps go to those routes which 404 until
  built.
- [ ] **Top-bar delivery address + wallet badge omitted.** The Flutter top bar
  shows the default delivery address and a pending-online-payment wallet badge;
  addresses surface is now at `/account/addresses` (built). Wallet badge and
  default address display in the top bar still deferred.
- [x] **Pending-invite home callout.** The invitations accept/decline surface is
  now built at `/invitations`. Home callout wiring is still deferred — add an
  InviteCard prelude to the home feed when demand exists.
- [ ] **Hero/spotlight are single-card (no auto-advance carousel).** The feed
  composer emits one banner/spotlight per block (as the mobile app does), so the
  multi-slide auto-advancing carousel + Ken-Burns/shimmer animations weren't
  needed. Add them if a multi-slide hero placement is introduced. Trust strip is
  the static row (mobile's rotating-carousel variant not ported).
- [x] **Merchants hub + invitations + shop catalog.** Built:
  `/invitations` — Pending/History tabs, InviteCard with Accept/Decline + busy
  state, celebrating on accept.
  `/merchants` — linked shops from `/api/me/links`, role filter
  (all/customer/supplier), MerchantCard with banner/logo/role-pill/invoice-count/
  activity row + quick-links strip.
  `/merchants/[role]/[id]/catalog` — category pill strip, search input (debounced
  220ms), 2–4 col product grid, pagination, skeleton/empty/error states.
  Lives in `src/features/merchants/` + `src/app/invitations/` +
  `src/app/merchants/`.
- [x] **Notifications.** Built — a header bell with a live unread badge
  (`NotificationsProvider` polls `/notifications/unread-count` every 60s + on
  focus, only while signed in) and a `/dashboard/notifications` inbox page
  (per-kind icons, relative time, mark-read on tap, mark-all-read, paginated).
  Mirrors merchant-web. NOTE: a dedicated pending-invitations accept/decline
  surface is still not built on customer-web (invite notifications link to
  `/dashboard` for now) — see invitations follow-up.

## Layout / shell debt

- [ ] **No app shell yet.** `/account` uses the top `AppHeader`. Decide the
  customer navigation shape (top nav vs sidebar) when the home is built; keep it
  full-width and responsive per CLAUDE.md.

## Catalog module (shop, categories, spotlights)

- [x] **Shop profile (`/shop/[slug]`).** Header (banner, logo, name, rating, product
  count), paginated 2–4 column product grid, infinite-scroll, sort chips.
  `generateMetadata` on the server wrapper. Lives in
  `src/app/shop/[slug]/page.tsx` + `src/features/catalog/components/shop-profile-view.tsx`.
- [x] **Categories grid (`/categories`).** Full category tree from
  `/api/categories/tree`, 3–6 column responsive grid, skeleton + empty/error
  states. Lives in `src/app/categories/page.tsx` + `…/categories-grid.tsx`.
- [x] **Category products (`/c/[slug]`).** Category header, child-category chip
  strip, sort bar, paginated 2–4 column product grid, infinite-scroll.
  `generateMetadata` on the server wrapper. Lives in `src/app/c/[slug]/page.tsx`
  + `…/category-products-view.tsx`.
- [x] **Spotlights list (`/spotlights`).** Full-page list of brand spotlights from
  `/api/home/feed`, 16:9 image cards linking to `/shop/[slug]`, skeleton + empty/
  error states. Lives in `src/app/spotlights/page.tsx` +
  `…/spotlights-list-view.tsx`.
- [x] **Spotlight "View all" link.** `src/features/home/components/brand-spotlight.tsx`
  now links to `/spotlights`. Done in the cross-link wiring pass.
- [x] **PDP (`/p/[id]`).** Full product detail page — SSR with `generateMetadata`,
  image gallery (carousel + thumbnail strip), variant picker, price block (flash
  countdown), stock chip, offers strip, FBT rail, specs section, reviews section
  (summary histogram + cursor-paginated list + write/edit/delete modal), wishlist
  heart, share button, sticky Add-to-cart / Buy-now / qty-stepper action bar.
  Lives in `src/app/p/[id]/page.tsx`, `src/features/pdp/`, `src/features/reviews/`.
- [x] **Home's `productHref` uses `/product/${id}` not `/p/${id}`.** Updated in
  the cross-link wiring pass — `product-tile.tsx` now returns `/p/${id}`.

## Search module

- [x] **Search page (`/search`).** Full-featured search — debounced input (250ms)
  synced to `?q=` URL param, autocomplete dropdown (product names + trending
  terms via `/api/search/autocomplete`), trending hints strip + recent-search
  history (localStorage, `useSyncExternalStore`-powered) when idle, results list
  with semantic/AI-ranked badge, filter/facet panel (rating, price range, in-stock),
  skeleton + empty + error states, keyboard navigation (↑↓ arrows, Enter, Escape).
  BFF routes at `/api/search`, `/api/search/autocomplete`, `/api/search/hints`
  were already present. Lives in `src/app/search/page.tsx` +
  `src/features/search/` (`types`, `schema`, `api`, `use-recent-searches`,
  `components/*`).
- [ ] **Search result taps go to `/p/[id]`.** This is already wired; requires PDP
  to be built at that route (see catalog module).
- [x] **Search filters wired to the backend.** `POST /search` now accepts
  `filters.priceMin/priceMax/ratingMin/inStock` plus top-level `includeFacets`,
  and returns `facets` (price bounds, `ratingBuckets.ge1–ge5`, `inStockCount` —
  no `brands`). `features/search/api.ts` sends them again, so the filter panel
  actually appears (it is gated on facets being present).
- [ ] **Filter facets: brands and shopIds.** The search facet payload
  deliberately omits `brands` (the marketplace listing facet shape
  `{brand, count}` and the Flutter `BrandFacet` shape `{shopId, name, slug}`
  disagree — reconcile that first). Add a brand strip + `shopIds` filter to
  the web panel and the search backend once the shape is settled.

## Cart / Checkout / Addresses

- [x] **Cart page (`/cart`).** Qty stepper capped at stock, remove + undo toast,
  savings + bill card, empty-state CTA, checkout button gated on auth (redirect
  to `/login?next=/checkout`). Lives in `src/app/cart/page.tsx`.
- [x] **Checkout page (`/checkout`).** Address selector (inline add-address form),
  coupon code + auto-apply on load, wallet toggle, COD vs Pay Online selector,
  bill breakdown, Place Order with idempotency key, ≥₹500 confirm dialog.
  Online: place → pay → Razorpay sheet → sync → route `/orders/[id]?toast=`.
  Lives in `src/app/checkout/page.tsx` + `src/features/checkout/`.
- [x] **Addresses page (`/account/addresses`).** List/add/edit/delete/set-default
  with validation (phone 10 digits, pincode 6). Lives in
  `src/app/account/addresses/page.tsx` + `src/features/addresses/`.
- [x] **Order detail toast messaging.** The checkout flow redirects to
  `/orders/[id]?toast=payment_success|payment_pending|payment_dismissed|payment_failed`.
  Order detail page reads `searchParams.toast` via `use(searchParams)` and
  initialises the Snackbar with the matching message on first render.

## Deals + Banner detail

- [x] **Deals page (`/deals`).** Flash-deals grid (2–4 col responsive) with live
  countdown chip, brand-spotlight cards. Reads from `/api/home/feed`. Lives in
  `src/app/deals/page.tsx` + `src/features/deals/components/deals-view.tsx` +
  `flash-deals-grid.tsx` + `spotlights-list.tsx` + `countdown-chip.tsx` +
  `deals-skeleton.tsx`.
- [x] **Banner detail page (`/banners/[id]`).** Full-bleed hero image with gradient
  overlay + brand label/title/subtitle/CTA, "Up to N% OFF" deal strip + trust
  chips, 2–4 col product grid with per-card discount badges, sale price vs
  crossed-out price, "You save" line and rating pill. Reads `/api/banners/:id/slide`.
  Lives in `src/app/banners/[id]/page.tsx` + `src/features/deals/components/
  banner-detail-view.tsx` + `banner-hero.tsx` + `banner-deal-strip.tsx` +
  `banner-product-card.tsx` + `banner-skeleton.tsx`.
- [ ] **BFF `/api/banners/:id/slide` already existed** (built by foundation agent).
  Deals page does not add a new BFF route — it reuses `/api/home/feed`.

## Quality / infra debt (applies to both web apps)

- [x] **Vitest suite + CI wired.** `npm test` covers the auth schemas, shared
  formatters, and the home mapper/composer/format (`src/features/home/home.test.ts`).
  The `customer-web` CI job runs lint+typecheck+test+build. Still worth adding:
  BFF route-handler tests and `extractError`.
- [ ] **Middleware does not protect `/invitations` and `/merchants`.** The
  PROTECTED array in `src/middleware.ts` and the `matcher` config need
  `/invitations/:path*` and `/merchants/:path*` added so cookieless visitors
  get redirected to `/login`. Currently `RequireAuth` is the only gate — the
  middleware edge gate is missing.
- [ ] **Enforcement tooling not wired.** Strict `tsconfig` flags, lint rules
  banning raw hex / arbitrary Tailwind values / inline numeric styles, CI,
  commitlint + husky. CLAUDE.md conventions are followed but not gated.
- [x] **B2B ledger (invoices + caution + quotations).** Built: `/merchants/[role]/[id]/invoices`
  (paginated list, party + vendor, status chips, skeleton/empty/error), `/merchants/[role]/[id]/invoices/[invoiceId]`
  (items table, GST line, totals, counterparty), `/merchants/[role]/[id]/caution`
  (balance card with breakdown stats, pending requests with cancel + Pay Online via Razorpay,
  txn history ledger, request deposit form), `/merchants/[role]/[id]/quotations`
  (list with status chips, PDF download), `/merchants/[role]/[id]/quotations/[qid]`
  (items + totals, Accept/Decline confirm dialogs, Withdraw for REQUESTED, invoice link
  after accept), `/merchants/[role]/[id]/request-quote` (searchable catalog, category chips,
  qty stepper, confirm panel with note, submit). Lives in `src/features/merchant-ledger/` +
  `src/app/merchants/[role]/[id]/`.

## Cross-app

- [ ] **Keep tokens + auth + CLAUDE.md in sync with `merchant-web`** when changing
  shared bits (they are duplicated, not extracted). Note merchant-only token
  accents (flashDeal/whatsapp) do not belong here. customer-web now also defines
  a `promo` token group (flash-deal peach/orange + spotlight yellow) used by the
  home feed — added to both `tokens.ts` and the `@theme` in `globals.css`.
