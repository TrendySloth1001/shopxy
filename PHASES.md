# ShopXY — Marketplace Build Phases

Single source of truth for the marketplace-pivot work. Each phase has a defined scope, deliverables, tests, and a demo flow. Phases are sequential — each depends on its predecessor.

**Product positioning** (locked in before P0): ShopXY is a **marketplace** where any logged-in customer can browse any published shop. The existing B2B per-shop relationship (invited Parties + invoice ledgers) is retained — those customers can still deal with their linked merchants — but the catalog is open to everyone.

**Scope rule throughout**: We build **backend + merchant Flutter app** in each phase. The customer Flutter app's wiring is deferred; the static UI in `customer/lib/features/home_v2/` shows the design target we're powering. Backend endpoints + tests prove the contract.

## Status

| # | Phase | State | Tests | Customer-side wiring |
|---|---|---|---|---|
| 0 | Foundations (Shop, image pipeline, Redis, role enum) | ✅ done | 8 | deferred |
| 1 | Catalog enrichment (reviews, ratings, tags, totalSold) | ✅ done | 10 | deferred |
| 2 | Banners + Categories taxonomy | ✅ done | 12 | deferred |
| 3 | Flash Sales (model, atomic claim, cron, UI) | ✅ done | 12 | deferred |
| 4 | Brand Spotlight + Editorial Collections | ✅ done | 15 | deferred |
| 5 | Event ingestion (`ProductEvent`, RecentlyViewed) | ✅ done | 10 | deferred |
| 6 | Trending + Recommendations | ✅ done | 7 | deferred |
| 7 | Merchant Analytics dashboard | ✅ done | 7 | merchant only |
| 8 | Search backend (Postgres FTS + hints) | ✅ done | 6 | deferred |
| 9 | Paid promotions (sponsored slots + billing) | ✅ done | 8 | merchant only |
| C | Customer-side wiring (rip out `home_v2_sample_data` → API) | ✅ done | 9 | customer wired |

**Backend test suite**: `cd backend && npm test` — currently 116/116 passing in ~6s. Tests run against the dev Postgres + (optional) Redis with try/finally cleanup; flash-sale tests skip Redis-only paths when Redis isn't reachable.

**Customer test suite**: `cd customer && flutter test` — Phase C added 6 home-feed tests (3 mapper, 3 widget). Customer-app analyze is clean.

## Locked decisions

1. **Roles**: `Role { OWNER, CUSTOMER }` on `User`. Merchant *is* admin for their own shop. Cross-shop curation gated by `User.isPlatformAdmin: Boolean` (flag-flip per account, defaults false).
2. **Image hosting**: existing MinIO via `upload` module. Sharp pipeline encodes uploads to WebP (q=75) in 3 sizes (`-sm`/`-md`/`-lg`, 160/400/800 wide). `urlFor(url, 'sm')` swaps the size token without re-querying.
3. **Reviews gating**: only buyers with a CONFIRMED `InvoiceItem` for the product. DRAFT invoices don't unlock.
4. **Admin UI**: inside `frontend/` (merchant app) behind `isPlatformAdmin` route guard. No separate admin app.
5. **Categories**: ship with `parentId` + `slug` from day one. Backfill seeds all existing rows at root; admin re-parents via UI.
6. **Sponsored slots ratio** (Phase 9): 1 in 5 product-rail items.
7. **Locale**: INR + en-IN hardcoded.

## Architecture snapshot

```
backend/                  Express + Prisma + Postgres + MinIO + Redis (graceful)
  src/
    infra/
      redis.ts            singleton client, graceful degradation
      scheduler.ts        node-cron registry (flash-sale flush + sweep)
      http/app.ts         pure factory — supertest mounts this
      http/server.ts      lifecycle + startScheduler + signal handlers
    modules/              one folder per feature {service,controller,routes}.ts
      shop                P0 — marketplace shop profile
      reviews             P1 — purchase-gated reviews + denorm recompute
      banners             P2 — hero/ad-strip/promo + Redis cache
      flash-sales         P3 — atomic claim, Redis counter, DB-lock fallback
    shared/
      cta-target.ts       DSL parser: category:slug | product:id | url:https://…
      http/
        requireRole.ts    requireRole(Role[]) + requirePlatformAdmin
        resolveShop.ts    middleware → req.shopId from caller's user
  tests/                  vitest, supertest-driven integration tests
    helpers/setup.ts      createTestUser / createTestProduct / recordTestPurchase
    {shop,upload,products,reviews,banners,categories,flash-sales}/

frontend/                 merchant Flutter app
  lib/features/
    shop                  P0 — Shop profile editor
    reviews               P1 — read-only review list per product
    admin                 P2 — Banner Manager + Category Taxonomy
    flash_deals           P3 — Live/Scheduled/Past tabs + editor

customer/                 customer Flutter app
  lib/features/home_v2/   the static UI we're powering (P0-built, then unchanged)
```

## Phase 0 — Foundations

**Done.** All 8 sub-tasks complete.

### Deliverables

- **Role enum + `isPlatformAdmin`** on User. Existing `OWNER`/`CUSTOMER` string values preserved via in-place `USING role::"Role"` cast.
- **`Shop` model** (1:1 with merchant User). Backfilled one shop per OWNER. Public read-only by slug — unpublished shops 404 (no info leak).
- **`Product.shopId` + `Product.isPublished`**. Cross-tenant lockdown via `resolveShop` middleware → `req.shopId` → service `where: { shopId }` everywhere.
- **Image pipeline**: Sharp + WebP encoder, 3 size variants per upload. 280 KB JPEG source → 3.4 KB / 15 KB / 53 KB (sm/md/lg).
- **Redis client** with graceful degradation: backend boots whether or not Redis is reachable; cache helpers no-op when `redisAvailable() === false`.
- **Merchant Shop Profile page** (`features/shop/presentation/pages/shop_profile_page.dart`): logo + banner uploaders, name, tagline, publish toggle with confirm.
- **Dashboard cross-tenant fix + heavy lowStock query**: previously aggregated all shops, now scopes to caller; replaced "load every active product into JS" with single indexed SQL count.

### Endpoints

```
GET  /me/shop          (OWNER)
PUT  /me/shop          (OWNER)
POST /me/shop/publish  (OWNER) { isPublished }
GET  /shops/:slug      (public, only published)
POST /upload           (OWNER) — returns { id, url, variants: { sm, md, lg } }
```

### Tests

`tests/shop/` (9), `tests/upload/` (4), `tests/products/` (7 — multi-tenant + lowStock SQL). Verifies cross-tenant probes return 404, image variants shrink as expected.

### Known carry-forward debt (still open)

- **Other modules still single-tenant**: vendors, parties, invoices, challans, payments, stock services don't filter by `shopId`. Latent bug from the pre-marketplace era; will surface when a second merchant has meaningful data. Multi-week refactor — not blocking marketplace launch but blocks "two competing merchants on the same instance."
- **Shadow DB broken** in the repo's migration history (`apply_invitations_notifications` doesn't apply cleanly to an empty DB). All P0+ migrations are written manually + executed with `prisma db execute` + `prisma migrate resolve --applied`. Fix when convenient; not blocking.
- **Sample products** all backfilled to shop #1. Shop #2's owner sees an empty catalog.

## Phase 1 — Catalog enrichment

**Done.** 10 new tests.

### Deliverables

- **`ProductReview` model**: `@@unique([productId, userId])` makes "edit my review" a same-row upsert. DB `CHECK rating BETWEEN 1 AND 5` is defence-in-depth.
- **Product denorms**: `ratingAvg`, `ratingCount`, `tags String[]`, `totalSold Int`. `totalSold` backfilled from existing CONFIRMED invoices in the migration.
- **Review gate** (`canReview`): a user can review product P iff there exists an `InvoiceItem.productId = P` whose invoice is `status: 'CONFIRMED'` and whose `party.linkedUserId = caller.id`. Tested — DRAFT invoices explicitly do *not* unlock.
- **Denorm recompute** inside the same Prisma transaction as the review write/delete. No drift possible.
- **Merchant editor** updates: chip-input for tags + reviews icon in product editor AppBar → opens `ProductReviewsPage` with summary card and infinite scroll.

### Endpoints

```
POST   /products/:id/reviews          { rating 1-5, title?, body? }  (auth, gated)
DELETE /products/:id/reviews/mine     (auth)
GET    /products/:id/reviews          (public, cursor pagination)
PATCH  /products/:id { tags: [...] } (OWNER, scoped to shopId)
```

## Phase 2 — Banners + Categories taxonomy

**Done.** 12 new tests.

### Deliverables

- **`Banner` model** with `BannerPlacement enum (HERO | AD_STRIP | PROMO | CURATED_RAIL)`, scheduling window, optional `sponsorShopId` (for Phase 9).
- **CTA target DSL** at `shared/cta-target.ts`: `category:<slug>` | `product:<id>` | `collection:<slug>` | `url:https://…`. Rejects `javascript:` schemes (XSS guard).
- **Redis cache** per placement (`banners:active:HERO`, TTL 60s). Invalidated on any write — including the cross-placement case when a banner moves between placements.
- **Category taxonomy**: `parentId` (self-FK with SetNull on parent delete), `slug` auto-derived with `-2`, `-3`, … suffix disambiguation. Cycle prevention walker rejects self-parent and any re-parent that would create a loop (depth-bounded so a corrupted tree can't hang the request).
- **`GET /categories/tree`** returns nested children in one query (single `findMany` + O(N) in-memory link), beats N recursive CTE calls for the depths we expect.
- **Merchant Flutter — admin section** (gated by `isPlatformAdmin`):
  - `AdminBannersPage`: list grouped by placement, status chip (Live/Scheduled/Expired/Off).
  - `AdminBannerEditorSheet`: image picker, placement dropdown, CTA target builder, hex colour inputs, date-time pickers, **live preview** that mirrors the customer hero card.
  - `AdminCategoryTaxonomyPage`: expandable tree, inline edit, parent dropdown auto-filtered to avoid cycles.

### Endpoints

```
GET    /banners?placement=HERO             (public, Redis-cached 60s)
GET    /admin/banners                      (platform admin)
POST   /admin/banners                      (platform admin)
PATCH  /admin/banners/:id                  (platform admin)
DELETE /admin/banners/:id                  (platform admin)

GET    /categories/tree                    (OWNER; returns nested children)
POST   /categories  { parentId? }          (OWNER; auto-slug)
PATCH  /categories/:id { parentId?, ... }  (OWNER; rejects cycles with 400)
```

## Phase 3 — Flash Sales

**Done.** 12 new tests including the concurrent-claim invariant.

### Deliverables

- **`FlashSale` model** with denormalised `soldCount`, scheduling window, CHECK constraints (`stock_limit > 0`, `flash_price >= 0`, `end_at > start_at`).
- **Partial unique index** `flash_sales_one_active_per_product (product_id) WHERE is_active = true` — Postgres-side enforcement that two concurrent sales can't exist on the same SKU. (Prisma 7 can't express partial indexes natively; raw DDL.)
- **`claim(productId, qty)` — two-layer race protection**:
  1. **Redis** `INCRBY flash:{id}:sold q`. If the new total exceeds `stockLimit`, `DECRBY q` to roll back and return `out_of_stock`.
  2. **Postgres** fallback via `SELECT … FOR UPDATE` inside a transaction when Redis is offline. Same invariant.
- **`release(productId, qty)`** mirrors claim — same two-layer model, clamps Redis counter at zero.
- **`flushSoldCountersToDb()`** cron tick (every 60s) writes Redis values verbatim to Postgres `soldCount`. **`sweepExpired()`** (every 5min) flips `is_active=false` on rows past `endAt`.
- **`scheduler.ts`** node-cron registry. Disabled via `NODE_ENV=test` or `DISABLE_CRON=true` so vitest runs never fire timers.
- **Merchant Flutter — Flash Deals page**: Live / Scheduled / Past tabs with sold-progress bar + cancel. Editor sheet has product picker (autocomplete on `/products?search=`), live `% off MRP` helper, start/end date-time pickers, **live preview matching the customer flash card**.

### Concurrency-safety test (`flash-sales.test.ts`)

```ts
// 100 parallel claims against limit=20 → EXACTLY 20 successes
const attempts = await Promise.all(
  Array.from({ length: 100 }, () => flashSalesService.claim(product.id, 1)),
);
const successes = attempts.filter((r) => r.ok).length;
expect(successes).toBe(20);
```

### Endpoints

```
POST   /me/flash-deals             { productId, flashPrice, stockLimit, startAt, endAt }
GET    /me/flash-deals?status=…    (active | scheduled | past | all)
GET    /me/flash-deals/:id
PATCH  /me/flash-deals/:id
DELETE /me/flash-deals/:id         (soft cancel — isActive=false)

GET    /flash-deals/active         public, ordered by endAt asc
```

### Carry-forward debt

- **No customer-checkout integration yet** — `claim()` / `release()` are tested helpers waiting for the customer purchase path. When that lands, it wraps `claim()` around the line-price resolution.

## Phase 4 — Brand Spotlight + Editorial Collections

**Done.** 15 new tests (8 brand-spotlight, 7 collections).

### Deliverables

- **`BrandSpotlight` model** with `BrandSpotlightStatus enum { PENDING, APPROVED, REJECTED }`, `[startAt, endAt]` window (CHECK `end_at > start_at`), reviewer audit trail. Merchant submits → admin reviews → only APPROVED + currently-in-window rows surface publicly. Cancel is allowed only while PENDING (audit kept for the rest).
- **`Collection` + `CollectionItem` models**: slug-keyed, admin-curated lists. `replaceItems` is a single transaction (delete + bulk createMany) — simpler than diffing on the client, fine at the small N curated lists carry. Slug auto-suffix on collision (`-2`, `-3`) and an explicit `slug` field on update goes through the same path.
- **Admin cross-shop product picker** (`GET /admin/collections/_search/products?q=`): platform-admin-only, name + SKU contains, returns 20 light summaries with shop info. Needed because the admin curator picks across all shops, while the existing `/products` endpoint is OWNER-scoped to one shop.
- **CTA target DSL reused** from P2 (`shared/cta-target.ts`) — validates both spotlight CTA + collection CTA at write time.
- **Merchant Flutter**:
  - `SpotlightRequestPage` — image picker, deal copy, scheduling window, hex colours, CTA target builder; existing requests list with status chip (Pending / Approved / Rejected + reason) and cancel button for pending rows.
  - `AdminSpotlightApprovalPage` (platform admin) — Pending/Approved/Rejected/All filter chips, preview card with shop attribution, approve / reject (with reason dialog).
  - `AdminCollectionsPage` + `AdminCollectionEditorPage` (platform admin) — list with item-count and publish chip; editor combines meta + cover image + drag-drop product list (ReorderableListView) + autocomplete picker that calls the cross-shop search endpoint.

### Endpoints

```
POST   /me/brand-spotlight/request        (OWNER+resolveShop) — lands as PENDING
GET    /me/brand-spotlight                (OWNER) — caller-shop only
DELETE /me/brand-spotlight/:id            (OWNER) — only while PENDING (409 otherwise)

GET    /admin/brand-spotlight?status=…    (platform admin)
GET    /admin/brand-spotlight/:id         (platform admin)
PATCH  /admin/brand-spotlight/:id/approve (platform admin)
PATCH  /admin/brand-spotlight/:id/reject  (platform admin) { reason }

GET    /brand-spotlights/active           (public) — APPROVED + now ∈ [startAt, endAt]

GET    /admin/collections                 (platform admin)
GET    /admin/collections/:id             (platform admin) — full detail + items
POST   /admin/collections                 (platform admin)
PATCH  /admin/collections/:id             (platform admin)
DELETE /admin/collections/:id             (platform admin)
PUT    /admin/collections/:id/items       (platform admin) — replaces full item list
GET    /admin/collections/_search/products?q=  (platform admin) — cross-shop picker

GET    /collections                       (public) — only `isPublished`
GET    /collections/:slug?cursor=&limit=  (public) — 404s on unpublished
```

### Carry-forward debt

- **Admin product picker is unbounded by shop scope** — fine for now (admin sees everything), but Phase 9 (paid promotions) may want a `?shopId=` filter so a merchant-facing promotion editor can reuse the same endpoint with restricted reach.

## Phase 5 — Event ingestion

**Done.** 10 new tests.

### Deliverables

- **`ProductEvent` model** (BIGINT id, `client_uuid @unique` for idempotency, JSONB `meta`, nullable `user_id` + `session_id`). Indexes mirror three hot read patterns: `(product_id, event_type, occurred_at)`, `(user_id, occurred_at)`, `(occurred_at)` for the prune scan. Enum: `IMPRESSION | TAP | VIEW | ADD_TO_CART | PURCHASE | WISHLIST_ADD`.
- **`RecentlyViewed` materialised table** — `@@unique([userId, productId])` makes the per-VIEW update a single upsert. The 20-row cap is soft: the hourly trim cron keeps each user bounded; we tolerate a brief overshoot rather than paying a DELETE on every ingest.
- **Ingest service** with the right primitives:
  - **Pre-flight filter** of unknown productIds in one query — silent drop + report back in the response so clients can prune local buffers (no 4xx-the-whole-batch on one stale id).
  - **`createMany({ skipDuplicates: true })`** swallows clientUuid collisions at insert time. A retried POST is a no-op.
  - **VIEW side-effect** dedupes within the batch on `(userId, productId)` so each distinct product is one upsert, not N.
  - **User attribution** comes from the JWT — clients can't mix user ids in the body to fabricate someone else's activity.
- **Cron jobs** (`scheduler.ts`):
  - **Hourly** — `eventsService.trimRecentlyViewed()`. Single-pass DELETE with `ROW_NUMBER() OVER (PARTITION BY user_id …)` to cap each user at 20 rows.
  - **Daily 03:00** — `eventsService.pruneOldEvents()`. Drop `product_events` older than 90 days; aggregates live in P6/P7 tables.
  - Both jobs disabled by `NODE_ENV=test` or `DISABLE_CRON=true`.
- **No merchant UI** — phase scope. The customer app's tracking service (P-customer) will be the primary caller.

### Endpoints

```
POST /v1/events                  (auth) — body { events: [{ clientUuid, eventType, productId, occurredAt, sessionId?, source?, meta? }] }, max 100/batch
                                          returns 202 { attempted, inserted, deduped, unknownProductIds[] }
GET  /me/recently-viewed         (auth) — caller's last 20, most-recent first, with light product summary
```

### Concurrency-safety / correctness highlights

- Retried POST of an identical batch returns `inserted: 0, deduped: N` — verified.
- Mixing a real and a ghost productId returns `inserted: 1, unknownProductIds: [ghost]` — verified.
- VIEW upsert keeps a single row per `(userId, productId)`, bumps `lastViewedAt` — verified.
- One user's RecentlyViewed never leaks into another user's `/me/recently-viewed` — verified.
- Trim helper caps each user at exactly 20 rows even after seeding 25 — verified.
- Prune helper drops rows older than 90d, leaves recent rows alone — verified.

### Carry-forward debt

- **Anonymous (pre-login) ingestion is not accepted yet** — POST /v1/events requires auth. Sessionised pre-login ingest lands when we wire customer-side tracking (event source can be sessionId-only for unauthenticated traffic).
- **No backpressure / rate limit** beyond the 100/batch cap. Add `express-rate-limit` if a malicious client tries to drown the table; for now low-volume + the unique index limits damage.

## Phase 6 — Trending + Recommendations

**Done.** 7 new tests.

### Deliverables

- **`TrendingScore` model** keyed by `(categoryId, productId, windowEnd)`. `categoryId = NULL` is the global ("All") bucket; per-category buckets share the same snapshot for cheap slicing. Old snapshots swept after 7d so the table stays bounded.
- **`recomputeWindow()`** — one big aggregate SQL (CASE-sum across event types) into a per-(product, category) score, then upserts into TrendingScore. Pre-flight re-checks product existence so a hard-delete between read and write doesn't FK-fail the whole transaction. Score formula (tunable):
  ```
  score = 0.05·impressions24h
        + 0.3 ·taps24h
        + 2  ·addToCart24h
        + 10 ·purchases24h
        + 1  ·wishlist24h
        − exp(−daysSinceListing / 30)
  ```
- **`RecommendationCache` model** — per-user shortlist keyed by `(userId, slot)`. Slot is open-ended text (`"for_you"`, `"because_you_viewed_X"`) so new surfaces don't need migrations.
- **`recomputeForUser(userId)`** — content-based scorer:
  1. Top-5 categories from the user's VIEW + WISHLIST_ADD events in the last 30d (wishlist weighted 3×).
  2. Candidates = trending rows in those categories.
  3. Bias: `×1.2` if user has interacted with the shop before; `×0.3` if already purchased.
  4. Persist top 30 ids in cache order so `findMany` re-ordering preserves rank.
- **`listRecommendations()`** reads cache → trending fallback for cold-start users.
- **Cron jobs** (`scheduler.ts`):
  - **Every 15min** — `trendingService.recomputeWindow()`. No-op when there are no events.
  - **Nightly 04:00** — `trendingService.rebuildAllRecommendations()`. Loops users with any activity in the last 30d.
  - Both disabled by `NODE_ENV=test` or `DISABLE_CRON=true`.
- **No merchant UI** — phase scope. Trending + recs surface only on the customer marketplace.

### Endpoints

```
GET /products/trending?categoryId=&limit=    (public) — latest snapshot, score desc
GET /products/recommended?slot=for_you       (auth)   — cache → trending fallback
```

### Correctness highlights

- Empty events window → recompute returns `{ products: 0 }` cleanly.
- PURCHASE outranks TAP for the same product (10× weight) — verified.
- categoryId filter selects only matching products — verified.
- Unpublished products are filtered out of `listTrending` even if they trended internally — verified.
- Cold-start user (no events) returns the global trending list from the recommendations endpoint — verified.
- Recommendations downrank already-purchased products at equal popularity — verified.
- Warm cache wins over trending fallback — verified.

### Carry-forward debt

- **`recomputeForUser` is sequential** in `rebuildAllRecommendations`. Fine at our scale; if active-user count grows past ~10k, batch in parallel with a small concurrency limit.
- **Score weights are hardcoded** in the service. Move to a `trending_weights` config table or env JSON when product wants to A/B them.

## Phase 7 — Merchant Analytics

**Done.** 7 new tests.

### Deliverables

- **`/me/analytics/products?from=&to=`** — single SQL aggregate with LEFT JOIN so products with zero traffic still appear (merchant table shows "no traffic" explicitly). Scoped via `resolveShop` middleware → `WHERE p.shop_id = $shopId`; cross-tenant probes never see a foreign row.
- **`/me/analytics/flash-deals/:id`** — per-hour series of sold / taps / views inside the flash window, with `stockLimit` / `soldCount` for the progress chip. 404 on a sale belonging to a different shop.
- **Range guards**: default last 7d, max 90d, `to > from` enforced by zod.
- **No materialised views yet** — the aggregate query already hits the `(product_id, event_type, occurred_at)` index. Promote to a daily MV when one shop's analytics read crosses ~300ms.
- **Merchant Flutter**:
  - `MerchantAnalyticsPage` — date-range picker (`showDateRangePicker`), KPI strip (`Wrap` of cards), sortable `DataTable` with client-side sort across all 8 numeric columns. Drawer entry under "Operations".
  - `FlashDealAnalyticsPage` — linked from each row of `FlashDealsPage` (new `bar_chart_outlined` icon). Sold-progress bar + hand-painted bar chart (no chart-package dependency) of hourly sold / taps / views.

### Endpoints

```
GET /me/analytics/products?from=&to=     (OWNER+resolveShop) — per-product roll-up
GET /me/analytics/flash-deals/:id        (OWNER+resolveShop) — sold + traffic time series
```

### Correctness highlights

- Events outside the requested window excluded — verified.
- CTR (`taps/impressions`) and CVR (`purchases/views`) math correct — verified.
- Cross-tenant: shop B never sees shop A's events or totals — verified.
- Range > 90d rejected with 400 — verified.
- `to <= from` rejected with 400 — verified.
- Flash deal: events outside `[startAt, endAt]` excluded; foreign-shop flash deal returns 404 — verified.

### Carry-forward debt

- **Chart is hand-painted** (no chart library). Swap to `fl_chart` when we add the second analytics surface (Phase 9 promotion spend over time).
- **No data export** (CSV / JSON download). Add when product asks.

## Phase 8 — Search backend

**Done.** 6 new tests.

### Deliverables

- **Generated tsvector column** on `products`: `to_tsvector('english', name || ' ' || coalesce(description, ''))`, `STORED`, with GIN index. Postgres 12+ generated columns mean every INSERT/UPDATE auto-derives the vector — no trigger or app-side bookkeeping.
- **Generated column kept out of the Prisma model** (Prisma can't model `GENERATED ALWAYS AS`). The search service queries through `$queryRaw` only; the surface area stays clean.
- **`SearchTerm` model** (`term @unique`, `queryCount`, `lastSearchedAt`) and **`SearchEvent` model** (per-request analytics with optional userId + sessionId). One row per term, one row per request — different cardinality kept on different tables.
- **`POST /search`** — `plainto_tsquery` so callers don't need FTS syntax, `ts_rank` for ordering, optional `categoryId` / `shopId` filters. Hits unpublished products are filtered out (`is_published = true AND is_active = true`).
- **Term canonicalisation** (`trim().toLowerCase().slice(0, 80)`) collapses "Saree", " SAREE ", and "saree" onto one SearchTerm row.
- **`GET /search/autocomplete`** — up to 8 product hits (FTS-ranked) + up to 4 prior `SearchTerm` matches (by `queryCount` desc). Two lists, not merged, so the client renders them differently.
- **`GET /search/hints`** — top 10 terms from the last 24h, **Redis-cached 5min** with on-write bust. Degrades cleanly when Redis is offline.
- **Analytics writes awaited** in the search path (~2ms cost) so callers can read-their-own-writes — important for the customer "did my search log?" feedback loop.

### Endpoints

```
POST /search                            (public) — body { q, filters?, sessionId? } → ranked hits + logs
GET  /search/autocomplete?q=…           (public) — product hits + prior-term matches
GET  /search/hints                      (public) — top trending terms (Redis-cached 5min)
```

### Correctness highlights

- Exact-token match returns the product, unrelated SKU does not — verified.
- Unpublished products excluded — verified.
- `shopId` filter scopes results to that shop — verified.
- Each `/search` call logs a SearchEvent and increments the SearchTerm `queryCount` — verified.
- Autocomplete returns both product hits and seed terms — verified.
- Hints include a freshly-recorded term — verified.

### Carry-forward debt

- **No language detection** — English stemming is hardcoded. Tamil / Hindi product names won't stem optimally; revisit when regional catalogues grow.
- **No "search hints" pruning cron** — the `search_terms` table grows monotonically. Add a daily prune (drop rows with `queryCount = 1` and `lastSearchedAt < 30d`) once it's >100k rows.
- **No customer UI** — phase scope. The customer global search bar wires in the customer-side phase.

## Phase 9 — Paid promotions

**Done.** 8 new tests.

### Deliverables

- **`Promotion` model** with `budgetPaise`, `dailyCapPaise`, `cpmPaise`, `[startAt, endAt]`, plus counters (`deliveredImpressions`, `spendPaise`, `spendTodayPaise`, `spendTodayDate`). CHECK constraints enforce positivity and `end_at > start_at`. Auto-pause writes `pausedReason` so the dashboard can surface "Budget exhausted" / "Daily cap reached" without a separate join.
- **`recordImpressions(promotionId, count)`** — single Postgres transaction: load → check day rollover → compute spend → maybe-pause → update. Inline auto-pause means the next impression read sees `isActive=false`.
- **Day rollover detection** without a cron — `spendTodayDate` is a Postgres `DATE`; when the first impression of a new day arrives it resets `spendTodayPaise` to 0. Quiet promotions get caught up by the hourly sweep.
- **Sponsored injection helper** — `injectSponsoredIntoRail(organic, enrich)` merges sponsored picks into a list at the locked **1-in-5** ratio (slots 0, 5, 10, …). `pickSponsored` does weighted-without-replacement sampling by remaining budget so well-funded promotions don't get starved by cheap ones still draining a tiny budget.
- **Hourly cron** `promotions:sweep` — verifies day-state for promotions with no impressions today (where the inline path can't fire) and auto-expires anything whose `endAt` has passed.
- **Merchant Flutter — `PromotionManagerPage`** — create sheet with autocomplete product picker, ₹-denominated inputs (auto-converted to paise), date-time pickers; list view with two progress bars (spend / budget, today's spend / daily cap), status chip, and cancel button. Drawer entry under "Manage".

### Endpoints

```
GET    /me/promotions          (OWNER+resolveShop)
GET    /me/promotions/:id      (OWNER+resolveShop)
POST   /me/promotions          { productId, budgetPaise, dailyCapPaise, cpmPaise, startAt, endAt }
PATCH  /me/promotions/:id      (any subset of editable fields)
DELETE /me/promotions/:id      (soft cancel — isActive=false, pausedReason='cancelled_by_merchant')
```

### Correctness highlights

- Cross-shop create rejected (product not in caller's shop → 404) — verified.
- `dailyCapPaise > budgetPaise` rejected at zod boundary — verified.
- Auto-pause kicks in exactly when `spendPaise ≥ budgetPaise` — verified.
- Auto-pause kicks in exactly when `spendTodayPaise ≥ dailyCapPaise`, with budget still remaining — verified.
- `recordImpressions` on a paused promotion does NOT accrue spend — verified.
- `pickSponsored` excludes draft products + expired windows — verified.
- Sweep cron flips `isActive=false` on windows past `endAt` — verified.

### Carry-forward debt

- **Customer rail doesn't call `injectSponsoredIntoRail` yet** — the helper exists; wiring into `listTrending` lands in the customer-side phase when there's a real surface to show ads on.
- **No Redis-buffered impression counter** — every impression hits Postgres directly through `recordImpressions`. Fine at low volume; promote to Redis INCR + minute-flush when one promotion crosses ~100 imp/sec.
- **CPM is the only billing model** — no CPC. Add when ads team wants it.

## Phase C — Customer-side wiring

**Done.** Backend aggregator + customer integration shipped. 9 new tests
(6 customer-side mapper + widget, 3 backend `/home/feed`).

### Deliverables

- **Backend `/home/feed`** — one-round-trip aggregator. Runs all section
  loads in parallel via `Promise.all`; each section is wrapped so a
  single failed read (e.g. empty trending snapshot) returns `[]` instead
  of failing the page. Returns hero / ad-strip / promo / curated-rail
  banners, brand spotlights, flash deals, active collections, global
  trending (top 30), and a slim root-categories puck list.
- **Backend `/me/home/personalized`** — auth-only counterpart, returns
  the caller's recently-viewed (filtered to published products) +
  their for-you recommendations.
- **`HomeFeedRemoteDataSource`** — talks to both endpoints; returns
  empty lists on 401 so the public feed degrades cleanly for the
  anonymous case.
- **`HomeFeedMapper`** — pure JSON → presentation model layer.
  Converts every backend shape into the existing widget models
  (`HeroSlide`, `FlashDealProduct`, `ProductCard`, etc.). Bad colour
  strings, missing nested fields, and unpublished products are all
  filtered without throwing.
- **`HomeFeedProvider`** (`ChangeNotifier`) — owns lifecycle: load,
  refresh, error retry, personalised-only re-fetch on login.
  Personalised data lands as a layered update so first paint isn't
  blocked on the authed call.
- **`TrackingService`** — batched POST `/v1/events` with a 20-event
  flush threshold and a 2s debounce. Events deduplicate server-side
  on `clientUuid`, so a retried batch is a no-op. Failed batches
  re-queue rather than dropping.
- **`HomeV2Page` rewrite** — consumes the provider; renders skeleton
  blocks on first load, an error/retry card if the initial call
  fails, and pull-to-refresh on the populated state. Each section
  collapses when its source list is empty so a sparse backend doesn't
  blank the page.
- **Every `home_v2_*` widget** updated to take its data via
  constructor (no more `HomeV2Data.X` static reads). Static-only
  surfaces (`HomeV2TrustStrip`, `HomeV2CategoryTabs`, search hints)
  read from a small `HomeV2StaticData` namespace.
- **Image pipeline**: `imageId`-based Unsplash URLs gone — every
  widget calls `resolveImageUrl(...)` on the URL the backend returned,
  which handles relative paths, loopback hosts, and absolute URLs.

### Endpoints

```
GET /home/feed                  (public)      → aggregator response
GET /home/category-rail?categoryId=&take=  (public) → per-category trending
GET /me/home/personalized       (auth)        → recentlyViewed + recommended
```

### Carry-forward debt

- **`VisibilityDetector`-based impression batching** — current code
  records IMPRESSION events for the visible top-of-list slice on
  mount. A scroll-aware visibility-50%-for-500ms gate is more
  faithful; tracked alongside the migration to `cached_network_image`.
- **Per-category rails are eager** — the customer fetches global
  trending only; the new `/home/category-rail` endpoint lets future
  surfaces fetch per-category lists lazily when the user taps a tab.
- **Search hints + delivery location** are still hardcoded constants
  in `HomeV2StaticData` — wire to `/search/hints` + a real geo
  service when those exist.

## Customer-side wiring (original notes)

Replace `customer/lib/features/home_v2/data/home_v2_sample_data.dart` with:

```
customer/lib/features/home_v2/
├── data/
│   ├── home_feed_dto.dart           NEW — typed model of /home/feed response
│   ├── home_feed_remote.dart        NEW — HTTP client
│   └── home_feed_repository.dart    NEW — caching + refresh logic
├── presentation/
│   ├── providers/
│   │   ├── home_feed_provider.dart       NEW (ChangeNotifier or Riverpod)
│   │   ├── recently_viewed_provider.dart NEW
│   │   └── tracking_service.dart         NEW (event batching, debounce)
│   └── widgets/                          existing — take DTO instead of static
```

Cross-cutting:

- Swap `NetworkImageBox` internals to `cached_network_image`.
- Implement impression tracking via `VisibilityDetector`: fire `IMPRESSION` event when a card stays ≥500ms ≥50% visible.
- Per-section skeleton/shimmer states.
- Empty/error states so one section's failure doesn't blank the page.

## How to verify / resume

```bash
# Backend dev loop
cd backend
npm run dev                          # boots server + cron + scheduler
npm test                             # vitest — currently 54/54
npx tsc --noEmit                     # type check

# Merchant Flutter
cd ../frontend
flutter analyze
flutter run

# Migrations (shadow-DB is broken; manual workflow)
# 1. Edit prisma/schema.prisma
# 2. mkdir -p prisma/migrations/<timestamp>_<name>
# 3. Write migration.sql manually
# 4. npx prisma db execute --file prisma/migrations/<...>/migration.sql
# 5. npx prisma migrate resolve --applied <timestamp>_<name>
# 6. npx prisma generate
```

## Test-data conventions

- `createTestUser({ role?, isPlatformAdmin? })` → returns `{ userId, shopId, shopSlug, accessToken, ... }`.
- `createTestProduct(shopId, overrides?)` → creates a product directly via Prisma.
- `recordTestPurchase({ shopId, buyerUserId, productId })` → creates a `Party` linked to buyer + a CONFIRMED Invoice with one InvoiceItem. Unlocks the review gate.
- `cleanupTestUser(ctx)` → cascades through invoices → parties → products → user. Idempotent for `finally` blocks.

Tests share the dev Postgres + (optional) Redis. They suffix every fixture with a random UUID so two test files can't collide on uniques. Redis tests self-skip when the connection isn't available.

## Inventory of every file added/modified (P0-P3)

### Backend
```
prisma/schema.prisma                                          (modified across P0-P3)
prisma/migrations/
  20260524180000_add_role_enum_and_platform_admin/migration.sql
  20260524181000_add_shop_model/migration.sql
  20260524182000_product_shop_and_publish/migration.sql
  20260525000000_product_reviews_and_denorms/migration.sql
  20260525120000_banners_and_category_taxonomy/migration.sql
  20260526000000_flash_sales/migration.sql
src/
  infra/
    redis.ts                                                  (new)
    scheduler.ts                                              (new)
    http/app.ts                                               (new — extracted from server.ts)
    http/server.ts                                            (modified — slim lifecycle)
  shared/
    cta-target.ts                                             (new)
    http/requireRole.ts                                       (modified — typed enum + requirePlatformAdmin)
    http/requireAuth.ts                                       (modified — Role enum, isPlatformAdmin)
    http/resolveShop.ts                                       (new)
  modules/
    auth/auth.service.ts                                      (modified — JWT carries isPlatformAdmin)
    upload/upload.service.ts                                  (modified — Sharp + WebP variants)
    upload/upload.routes.ts                                   (modified — returns {id, url, variants})
    products/products.service.ts                              (modified — shopId scoping, SQL lowStock, setPublished, tags)
    products/products.controller.ts                           (modified)
    products/products.routes.ts                               (modified — adds /publish)
    categories/categories.service.ts                          (modified — slug, parentId, getTree, cycle check)
    categories/categories.controller.ts                       (modified)
    categories/categories.routes.ts                           (modified — /tree)
    dashboard/dashboard.service.ts                            (modified — shopId scoping, SQL lowStockCount)
    dashboard/dashboard.controller.ts                         (modified)
    shop/{service,controller,routes,public.routes}.ts         (new)
    reviews/{service,controller,routes}.ts                    (new)
    banners/{service,controller,routes}.ts                    (new)
    flash-sales/{service,controller,routes}.ts                (new)
tests/
  helpers/setup.ts                                            (new — createTestUser, createTestProduct, recordTestPurchase, cleanupTestUser)
  shop/shop.test.ts                                           (9 tests)
  upload/upload.test.ts                                       (4 tests — uses Unsplash hot-link)
  products/products.test.ts                                   (7 tests)
  reviews/reviews.test.ts                                     (10 tests)
  banners/banners.test.ts                                     (7 tests)
  categories/categories.test.ts                               (5 tests)
  flash-sales/flash-sales.test.ts                             (12 tests)
vitest.config.ts                                              (new)
docker-compose.yml                                            (modified — adds redis service)
package.json                                                  (deps: sharp, ioredis, node-cron, vitest, supertest)
```

### Merchant Flutter
```
lib/features/
  shop/                                                       (new — P0)
    data/{models/shop.dart, datasources/shop_remote_data_source.dart}
    presentation/{providers/shop_provider.dart, pages/shop_profile_page.dart}
  reviews/                                                    (new — P1)
    data/{models/product_review.dart, datasources/reviews_remote_data_source.dart}
    presentation/pages/product_reviews_page.dart
  admin/                                                      (new — P2)
    data/{models/banner.dart, datasources/admin_banners_remote_data_source.dart}
    presentation/
      providers/admin_banners_provider.dart
      pages/{admin_banners_page.dart, admin_banner_editor_sheet.dart, admin_category_taxonomy_page.dart}
  flash_deals/                                                (new — P3)
    data/{models/flash_deal.dart, datasources/flash_deals_remote_data_source.dart}
    presentation/
      providers/flash_deals_provider.dart
      pages/{flash_deals_page.dart, flash_deal_editor_sheet.dart}
  products/
    domain/entities/product.dart                              (modified — denorms + isPublished + tags)
    data/models/product_dto.dart                              (modified — same)
    presentation/
      pages/add_edit_product_page.dart                        (modified — tags chip input + reviews icon)
      providers/products_provider.dart                        (modified — accepts tags)
  categories/
    domain/entities/category.dart                             (modified — slug, parentId, CategoryNode)
    data/{models/category_dto.dart, datasources/categories_remote_data_source.dart}    (modified — tree, parentId)
  auth/domain/entities/auth_user.dart                         (modified — isPlatformAdmin)
core/router/app_shell.dart                                    (modified — My Shop, Flash deals, Platform admin section)
main.dart                                                     (modified — wires Shop, AdminBanners, FlashDeals providers)
```
