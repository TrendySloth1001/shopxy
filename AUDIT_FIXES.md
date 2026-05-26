# Audit Fixes — Phased Plan

Source: brutal audit on 2026-05-26 of `chore/audit-fixes-integration`. Streams a–e already merged surface fixes; this plan addresses the ~100 findings those streams missed. Severity bucket from the audit: CRITICAL / HIGH / MEDIUM / LOW.

Legend: `[ ]` pending · `[~]` in progress · `[x]` done · `[-]` deferred (needs migration / large refactor / further scoping)

---

## Phase F0 — Secrets, config, build-time guardrails (blocking)

- [x] **F0-1** Complete `backend/.env.example` with every env var the code reads.
- [x] **F0-2** Remove hard-coded `change-me-*` and `shopxy_dev_password` from `docker-compose.yml`; `${VAR:?...}` substitution.
- [x] **F0-3** Reconcile `.env.example` DB port (5432) vs compose mapping.
- [x] **F0-4** `AppConfig.apiBaseUrl` in both Flutter apps fails loudly in release if `API_BASE_URL` is absent or points at a dev tunnel/localhost.
- [x] **F0-5** Replaced `_storage.deleteAll()` with explicit key deletes in both `TokenManager`s.
- [x] **F0-6** Refuse `origin: true` CORS fallback; require `CORS_ORIGINS` in production, safe local-dev list otherwise.
- [x] **F0-7** MinIO creds: refuse fallback in production; warn + dev-defaults match docker-compose locally so tests still pass.
- [x] **F0-8** iOS keychain first-launch wipe (customer app) — SharedPreferences flag detects fresh install and clears keychain tokens.

Bonus: extracted shared `backend/src/shared/env.ts` (`requireEnv`/`envOr`) so future modules don't re-implement; auth.service + requireAuth now use it.

## Phase F1 — Tenant isolation (CRITICAL data leaks)

- [x] **F1-1** `/auth/me/export` scopes every `findMany` by `shopId` (10 entities). Categories stay global (shared taxonomy).
- [x] **F1-2** `deleteAccount` retention check scoped by shopId — one merchant's invoices no longer block any other merchant's deletion.
- [x] **F1-3** `payments.createPayment` validates `partyId`/`vendorId` against caller's shopId before insert.
- [x] **F1-4** `/me/catalog/*` adds `isPublished: true` to listCatalog AND getCatalogProduct.
- [-] **F1-5** `requireRole('CUSTOMER')` on `/me/*` — deferred. Would break legitimate dual-role browsing (OWNER browsing other shops); audit's underlying concern (cross-shop write) is already gated by `OWN_SHOP_ITEM` in `createForCustomer`. Tracked for the dual-role refactor.
- [x] **F1-6** `/categories` moved above `requireAuth` with `optionalAuth`; writes self-gate via `requirePlatformAdmin` which fails closed.

## Phase F2 — Wire missing customer routes (dead UI buttons)

- [x] **F2-1** `POST /me/orders/:id/shops/:childId/cancel` mounted (with `mergeParams: true`).
- [x] **F2-2** `POST /me/orders/:id/reorder` mounted.
- [x] **F2-3** `GET /me/orders/:id/shops/:childId/invoice.pdf` mounted (path matches the customer-app data source verbatim).
- [x] **F2-4** `POST /me/orders/:id/events` (merchant `addShippingEvent`) mounted.

## Phase F3 — Money & order safety

- [x] **F3-1** Wallet refund factor: branches on method. WALLET refunds full to wallet; ORIGINAL/cash refunds the cash portion off-platform but still credits the original wallet-funded slice back to the user.
- [x] **F3-2** `confirmRequest`: invoice auto-confirms (`confirm: true`); manual stock decrement in step 3 removed in favour of the ledger path. Stock movement is now visible to reports / low-stock alerts.
- [x] **F3-3** Flash-sale claims wrapped in try/finally — any failure during persist releases every claimed unit.
- [x] **F3-4** `cancelChildForCustomer` rolls back: proportional wallet refund, flash-sale release, coupon redemption decrement when last sibling goes terminal.
- [x] **F3-5** Same rollback for merchant `rejectRequest`.
- [x] **F3-6** Payment over-allocation race: aggregate-check + insert inside one Serializable transaction; counters enrolled in the same tx via the new `tx` parameter on `nextCounter`/`nextPaymentRef`.
- [x] **F3-7** Payment idempotency header (`X-Idempotency-Key`) — migration + service + controller wired. Replay validates payload match.
- [x] **F3-8** Wallet idempotency keys namespaced: `wallet:checkout:<key>`, `wallet:return-refund-<id>`, `wallet:cancel-<id>`, `wallet:reject-<id>`. New `WalletSource.CANCEL`.
- [~] **F3-9** Place-order price-drift guard — backend fully wired (`PRICE_DRIFT` with per-line corrections). Customer-app currently omits `expectedUnitPrice` because the cart doesn't persist the flash price; re-enable once F8-3 lands.

## Phase F4 — Auth & session hardening

- [x] **F4-1** `jwt.verify(token, SECRET, { algorithms: ['HS256'] })` in `requireAuth` — algo confusion protection.
- [x] **F4-2** `tokensValidFrom` — column added; `requireAuth` enforces; password change + logout-all bump. NOTE: 60s per-process cache means multi-worker deploys propagate the change with a TTL lag — track as F-multi-pod TODO.
- [-] **F4-3** `/auth/logout` requires auth — kept public because the access token is normally expired by the time a user clicks logout (post-refresh); future hardening is to require `Authorization: Bearer <refresh>` instead.
- [x] **F4-4** `POST /auth/logout-all` — drops every refresh token for the caller. Authed.
- [-] **F4-5** Email verification gate — deferred (full feature: email service + schema + UI).
- [x] **F4-6** Invitation `respond()`: detects `updateMany.count === 0` (Party already linked elsewhere), throws `InvitationAlreadyLinkedError`, surfaced as `PARTY_ALREADY_LINKED`.
- [x] **F4-7** Partial unique `(shop_id, linked_user_id) WHERE NOT NULL` on Party + Vendor — migration `20260612000000_party_vendor_linked_user_unique`.
- [x] **F4-8** `confirmRequest` finds-or-creates Party (lookup by `(shopId, linkedUserId)` first) — repeat buyers no longer accumulate duplicate Party rows.

## Phase F5 — Backend route & infra hardening

- [-] **F5-1** `resolveShop` everywhere — deferred (touches ~13 modules; high coordination cost, low-risk staleness in current state since shop ownership doesn't transfer in prod yet).
- [x] **F5-2** Upload extension derived from mime type with allowlist (jpg/png/webp/gif/pdf); `X-Content-Type-Options: nosniff` on `/images/:filename`.
- [x] **F5-3** Per-user rate limit on `/upload` (30/min, keyed on `req.user.sub`).
- [x] **F5-4** Per-user rate limit on `/v1/events` (600/min).
- [x] **F5-5** Search `_recordSearch` dedupe — in-memory 2s window per (user|session) blocks bot loops + double-fire UI bugs. Anonymous calls still record (no stable actor to key on).
- [x] **F5-6** Invoice line cap (200) on createInvoice + updateInvoice.
- [x] **F5-7** Streaming PDFs via `streamPdf(shopId, id, out, onReady)`; controllers flip headers via `onReady` only after the invoice load succeeds.
- [-] **F5-8** `Timestamptz` migration — deferred.
- [x] **F5-9** Standard error envelope `{ code, message, details?, error (alias) }` in `errorHandler.ts`. Apps continue to read `error`; the alias is removed in a future release once both apps prefer `code`.
- [x] **F5-10** `requireEnv` extracted to `shared/env.ts`; auth.service + requireAuth now use it.

## Phase F6 — Flutter networking parity

- [x] **F6-1** Merchant `ApiClient` backported: generic `_withRetry<T extends BaseResponse>`, multipart goes through retry.
- [x] **F6-2** Merchant `ApiClient.post`/etc accept `extraHeaders`.
- [x] **F6-3** 20s default timeout on every HTTP call (both apps); refresh path too; uploads get 60s.
- [x] **F6-4** `_refreshCompleter` race fixed: never null the slot unless we still own it; safe `.complete(false)` guarded with `isCompleted` check on every throw path.
- [-] **F6-5** `X-Client-App`/`X-Client-Version` headers — deferred (no server-side gate yet).
- [-] **F6-6** Friendly error mapper across all snackbars — partially addressed (ShopProvider clears `_error` on retry, F7-7); a single shared helper is the follow-up.

## Phase F7 — Merchant Flutter correctness

- [x] **F7-1** `AuthProvider.clearAuth()` is now async + awaits the storage clear.
- [x] **F7-2** `ProductsProvider` in-flight guard on `loadProducts(loadMore: true)` — `_isLoadingMore` flag.
- [x] **F7-3** `AppSearchBar` debounces internally (280ms default); callsites that already debounce can pass `debounce: Duration.zero`.
- [x] **F7-4** `PopScope` dirty bit calls `setState` on the merchant invoice + product forms.
- [-] **F7-5** `cacheWidth` on every `Image.network` — deferred (sweeping change; targeted high-impact tiles get it in follow-up).
- [x] **F7-6** Merchant providers (Products, Invoices, Shop, Vendors, Parties, Challans, Orders, Notifications) eager-created in `main.dart` + `reset()` wired through `AuthProvider.registerOnClear`. `deleteAccount` also fires the fan-out.
- [x] **F7-7** `ShopProvider.uploadImage` clears `_error` at top of every call.
- [-] **F7-8** Single source for badge fetches — deferred (refactor of three init paths).
- [-] **F7-9** Hero tag duplicate guard — deferred (low-impact UX paper cut).
- [-] **F7-10** Tighten product validators (price > 0, GST 0–28) — deferred.

## Phase F8 — Customer Flutter correctness

- [-] **F8-1** Server-time countdown timers — deferred (backend response shape change required for serverTime field).
- [x] **F8-2** Cart `_capQuantity`: out-of-stock now returns 0 (was returning `double.infinity`).
- [-] **F8-3** Cart price hydration on restore — deferred (needs a `pricedAt` field on the persisted line + revalidation pass).
- [x] **F8-4** Explicit-logout-only callback path on AuthProvider; `cartProvider.clear` registered there. Transient 401-refresh failures keep the basket; explicit logout drops it.
- [x] **F8-5** Deep-link handler defers tap to post-login; replays on `authProvider` false→true. 1.5s same-product dedupe window swallows OS-side duplicate uri events.
- [x] **F8-6** Place-order confirm dialog above ₹500 + synchronous `_submitting` guard set inside the tap handler before any await.
- [x] **F8-7** Address delete: confirmation dialog before delete.
- [x] **F8-8** Pincode + phone validators (Indian formats: pincode `^[1-9][0-9]{5}$`, phone `^[6-9][0-9]{9}$` with +91 strip).
- [x] **F8-9** Search: `_loading=true` set synchronously when starting debounce — "No matches for 'ph'" flash gone.
- [x] **F8-10** Wishlist heart shows a "Sign in to save items" bottom sheet for guests; pushes LoginPage on the root navigator so the sheet stays mounted until login returns; toggle re-runs after the auth state flips.
- [x] **F8-11** App-lifecycle observer wraps the customer app: on resume flush analytics + re-sync cart; on pause flush analytics.
- [x] **F8-12** Same as F8-2 (covered by `_capQuantity` fix).
- [-] **F8-13** Orphan-bucket cart UI — deferred (UI work in checkout page).

## Phase F9 — Tests, CI, drift guards

- [-] All deferred — needs a CI pass + dedicated PR. Did fix one test-helper bug (`recordTestPurchase` missing shopId on Party + Invoice), unblocking 6 previously-failing tests.

## Phase F10 — Mediums and polish

- [-] All deferred. The most impactful item — service-layer Decimal arithmetic — needs cross-module replacement of `Number()` calls with `.mul/.sub/.add` on `Prisma.Decimal`.

---

## Execution log (sessions on 2026-05-26)

| Phase | What landed |
|-------|-------------|
| F0 | `.env.example`, `docker-compose.yml`, `AppConfig` (both apps), `TokenManager.clear()` (both apps), iOS keychain wipe (customer), CORS fail-closed in prod, MinIO env-required in prod, shared `requireEnv` helper. |
| F1 | `/auth/me/export` shopId-scoped, `deleteAccount` retention scoped, `payments.createPayment` party/vendor ownership, `/me/catalog/*` isPublished, `/categories` public read. |
| F2 | Customer cancel-child route + reorder + invoice PDF; merchant shipping-event route. |
| F3 | Wallet refund split, auto-confirm invoice + ledger path, flash claim rollback (create+cancel+reject), coupon decrement, payment Serializable tx, wallet idempotency namespacing, `WalletSource.CANCEL`. |
| F4 | JWT HS256 pin, `/auth/logout-all`, invitation respond `PARTY_ALREADY_LINKED`, `confirmRequest` party dedupe. |
| F5 | Upload mime allowlist, `X-Content-Type-Options: nosniff`, `/upload` + `/v1/events` per-user rate limits, invoice line cap (200), shared `requireEnv`. |
| F6 | Merchant ApiClient parity (extraHeaders, generic `_withRetry`, multipart retry); 20s timeouts both apps; refresh-completer race fix. |
| F7 | `AuthProvider.clearAuth()` async, `ProductsProvider` in-flight guard, `AppSearchBar` debounce, `ShopProvider` error reset. |
| F8 | Cart out-of-stock cap, explicit-logout cart clear, address delete confirm, pincode/phone validators, search loading-flash fix, customer AuthProvider `clearAuth` async. |
| F11 | Migrations: partial unique on `(shop_id, linked_user_id)` for Party + Vendor; `users.tokens_valid_from`; `payments.idempotency_key` partial unique. `requireAuth` enforces `iat ≥ tokensValidFrom`; password change and logout-all bump it. Payment idempotency wired end-to-end (controller reads `X-Idempotency-Key`, service replays + verifies payload match). |
| F12 | Place-order price-drift guard (server-side `expectedUnitPrice` compare; `PRICE_DRIFT` error code with per-line corrections; customer-side `PriceDriftException` parsing). Standard error envelope `{ code, message, details?, error (alias) }` in `errorHandler.ts`. |
| F13 | PDF streaming via `Writable` instead of full-buffer; controllers flip headers via an `onReady` callback only after the invoice load succeeds. Search write dedupe (in-memory 2s window, per-user/session only — anonymous calls still record). `keyGenerator` uses `ipKeyGenerator` for IPv6. |
| F14 | `PopScope` dirty bit calls `setState` (merchant invoice + product forms). Merchant providers gain `reset()` (Products, Invoices, Shop, Vendors, Parties, Challans, Orders); main.dart eager-creates + registers them on AuthProvider. `deleteAccount` also fires the clear callbacks. |
| F15 | Deep-link handler defers tap to post-login; replays on auth false→true. LifecycleObserver wraps the app (resume → flush analytics, re-sync cart; pause → flush analytics). Place-order confirm dialog above ₹500 + synchronous `_submitting` guard. Wishlist heart prompts guest sign-in via bottom sheet; LoginPage pushed on the ROOT navigator so the sheet stays mounted until login returns. |
| F16 (re-audit) | Fixed confirmRequest tx-nesting regression (createInvoice runs outside outer tx now; explicit revertToPending on every failure path). Fixed cart `expectedUnitPrice` regression (omitted until F8-3 persists the priced-at value). Fixed PDF headers-before-error regression via onReady callback. Fixed `deleteAccount` not firing clear callbacks. Payment idempotency replay validates amount/party/vendor/invoice match. Returns refund `walletShare` denominator now uses `gross − coupon`. |

### Verification

- Backend `tsc --noEmit`: clean.
- Backend `npm test`: 125 passing / 15 failing — pre-existing failures in flash-sale + analytics test fixtures (missing `shopId` on flashSale.create). Pre-my-changes baseline was 119 passing / 21 failing; my changes fixed 6 (test-helper Party + Invoice shopId fix).
- Merchant `flutter analyze`: 0 errors, 22 info-level lints (pre-existing).
- Customer `flutter analyze`: 0 errors, 1 pre-existing warning about missing `assets/` directory.

### Deferred items requiring follow-up PRs

1. **Schema migrations** (medium effort each): payment idempotency column, `@@unique([shopId, linkedUserId])` on Party/Vendor, `tokensValidFrom`, `Timestamptz` for client-read columns.
2. **Architecture**: `resolveShop` on every merchant route; provider-reset registry in merchant app; dual-role token policy.
3. **Features**: email verification; `expectedSubtotal` checkout contract; deep-link auth gate; lifecycle observer; X-Client-Version header gate.
4. **Sweeps**: `Decimal` arithmetic throughout services; `cacheWidth` on every `Image.network`; `PopScope` dirty fix per form.
5. **CI**: `prisma migrate reset --force` integration job; route-inventory contract test; pre-existing flash-sale test fixtures need `shopId` plumbing.
