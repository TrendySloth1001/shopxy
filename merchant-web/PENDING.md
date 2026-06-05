# PENDING.md — merchant-web

Deferred wiring and known stubs. **Read this before implementing a new feature**
— when you build something here, check whether it unblocks an item below and
wire it up. **When you stub, defer, or simplify something, add a row here** with
where it lives and what triggers finishing it.

Format: `[ ]` open · `[x]` done. "Trigger" = the feature whose arrival means
this should be revisited.

## Deferred wiring (stubbed — connect when the trigger lands)

- [ ] **Sidebar nav → real screens.** Built: `Products`, `Orders`, `Shop`,
  `My Carousels`, `Flash deals`, `Brand spotlight`, `Promotions`, `Coupons`,
  `Categories`, `Vendors`, `Customers` (parties) (+ Profile / Settings / Team /
  Payouts / Custom fields). The rest still land on the `/dashboard/[...section]`
  placeholder. Trigger: building each remaining section (invoices, quotations,
  challans, stock-adjustments, returns, reports, analytics) — add
  `app/dashboard/<section>/…`.
- [ ] **Dashboard row tap-through.** In `src/features/dashboard/dashboard-home.tsx`
  `DraftRow` and `ActivityRow` are display-only. Trigger: invoice / challan
  detail screens exist → link a draft to its invoice detail, and an activity row
  to its source doc (`tx.sourceType` `INVOICE`/`CHALLAN` + `tx.sourceId`).
- [ ] **Dashboard pending-invite callout.** Flutter shows a brand callout at the
  top of the dashboard for pending incoming invitations (party/vendor/team).
  Trigger: notifications/invitations feature on web → add the callout linking to
  the notifications screen.
- [ ] **Payout-setup nudge.** Flutter nudges Razorpay-Route payout onboarding
  once per session (behind ROUTE_SPLIT_ENABLED). Trigger: payouts / linked-account
  feature on web → add the nudge to the dashboard.
- [ ] **`dashboard:view` no-access state.** `src/app/api/dashboard/stats/route.ts`
  returns 403 for roles without the permission; the screen currently shows it as
  a generic error. Trigger: team/roles UI → render a dedicated "Dashboard hidden"
  view with a reload button.
- [ ] **Notification bell.** Flutter's dashboard app bar has a notification bell.
  Trigger: notifications feature on web → add it to the merchant shell header.

## Products — deferred / known gaps

- [ ] **Variants don't re-read on merchant detail/edit.** Backend
  `getProductById` (`backend/src/modules/products/products.service.ts`) uses
  `include: { category, images, stockTransactions }` and OMITS the `variants`
  relation, so `GET /products/:id` returns `variants: []`. Variants ARE persisted
  on create/update (create response includes them; the customer marketplace shows
  them) — but the merchant edit form's Variants section starts empty on reload and
  the detail page can't list them. Fix = backend includes variants in getById (or
  the web reads them elsewhere). We already guard against wiping: variants are only
  sent when axes are defined.
- [x] **Custom-field definitions UI.** Built at `/dashboard/custom-fields`
  (sections + definitions CRUD, templates). See the Shop/Settings section below
  for the remaining custom-field gaps (drag-reorder, icon picker).
- [ ] **OCR / barcode-scan helpers** from the Flutter add/edit (camera scan to
  prefill SKU/barcode) are not ported — native-camera features.
- [ ] **List filters aren't in the URL** (search/category/sort/page are local
  state) so they don't deep-link or survive refresh. Move to query params.

## Orders — deferred / known gaps

- [ ] **Restock-from-order flow.** Flutter lets the merchant tap a short line on a
  pending order to open a stock-in sheet, then confirm the draft inline so the
  shortfall clears without leaving the order. On web the shortfall banner + per-
  line stock chips are informational only. Trigger: stock-adjustments / stock-in
  + invoices web features land → wire the restock action on the detail page.
- [ ] **Shipping events are read-only.** The order detail renders the event
  timeline (`GET /orders/:id` → `events`), but there's no UI to *post* a
  milestone. Backend supports `POST /orders/:id/events`
  (PACKED/SHIPPED/OUT_FOR_DELIVERY/DELIVERED/RETURNED + courier/awb/eta). Trigger:
  fulfilment UX → add an "Update shipping" action.
- [ ] **Open-invoice CTA targets a placeholder.** The confirmed-order CTA links to
  `/dashboard/invoices/:id`, which currently lands on the `[...section]`
  placeholder. Trigger: invoices detail screen exists → it resolves automatically.
- [ ] **`orders:view` no-access state.** Flutter shows a dedicated "Orders hidden"
  view for roles without the permission; the backend `GET /orders` returns 403 and
  the web list currently shows it as a generic error. Trigger: team/roles UI →
  render a dedicated no-access view (same as the `dashboard:view` item above).

## Marketing — built & deferred / known gaps

- [x] **Full-page editors everywhere.** All marketing create/edit flows are now
  dedicated routes with a sticky two-column live preview (carousels `/new` +
  slide `/slides/new|[slideId]`; flash deals `/new` + `[id]/edit` + `[id]/
  analytics`; promotions `/new` + `[id]/edit`; spotlight `/new`) instead of
  modals. Shared `PageHeader`/`BackLink` (`src/shared/ui/page-header.tsx`) give
  every section a consistent toned masthead. Only destructive confirmations
  (cancel/delete) remain compact dialogs by design. Flash deals open a read-only
  detail page first (preview + inline analytics) with an Edit button — not
  straight into the editor.


- [x] **My Carousels.** `/dashboard/carousels` (list grouped by placement +
  new-carousel modal) and `/dashboard/carousels/[id]` (carousel meta with
  auto-save + slides list + slide editor modal with a live 7-template
  `HeroSlidePreview`). BFF: `api/carousels` (+ `[id]`, `[id]/slides`,
  `[id]/slides/[slideId]`) → `/me/carousels`.
- [x] **Flash deals.** `/dashboard/flash-deals` — Live/Scheduled/Past tabs,
  sold-bar tiles, editor modal with product picker + discount preview. BFF
  `api/flash-deals` (+ `[id]`) → `/me/flash-deals`.
- [x] **Brand spotlight.** `/dashboard/spotlight` — explainer + status cards
  (rejection reason) + submit modal (hero upload, colours, CTA DSL, schedule).
  BFF `api/spotlight` (GET list / POST `/request`) + `[id]` (cancel).
- [x] **Promotions.** `/dashboard/promotions` — spend + daily-cap bar cards with
  status/impressions + create modal (product picker, ₹ budget/daily/CPM →
  paise, schedule). BFF `api/promotions` (+ `[id]`) → `/me/promotions`.
- [ ] **Carousel slide drag-reorder.** Slides order by a numeric `sortOrder`
  field the merchant types; no drag handles. Trigger: polish pass.
- [x] **Slide "discounted products" (banner-products).** The slide editor (edit
  mode) has a "Discounted products" section: pick products, set a PERCENT/AMOUNT
  offer, reorder, remove, save. Wired to `GET`/`PUT /me/banners/:slideId/products`
  via `api/slides/[slideId]/products` (a slide is a Banner; ownership via
  `sponsorShopId`). Display-only offer — checkout still charges the normal price.
- [x] **Flash-deal detail + inline analytics.** Tapping a flash deal opens a
  read-only detail page (`/dashboard/flash-deals/[id]`) showing the customer-card
  preview, key facts, and analytics inline (claimed, views, taps, tap→buy, hourly
  series via `api/flash-deals/[id]/analytics` → `/me/analytics/flash-deals/:id`),
  with an Edit button → `[id]/edit`. The standalone analytics page was removed.
- [x] **Promotion edit + pause/resume.** Promo cards can edit budget/cap/CPM/
  schedule and pause/resume (`PATCH /me/promotions/:id`); cancelled promos stay
  terminal. (Promotion-level analytics / impression charts still TODO — only the
  live spend bars are shown.)
- [ ] **CTA-target preview links aren't resolved.** The slide/spotlight CTA
  stores `category:`/`product:`/`collection:`/`url:` but the web preview only
  renders the button label, not a click-through. Trigger: storefront routes on
  web → resolve the target.
- [ ] **Slide CTA shimmer / Ken-Burns animation.** The preview renders the
  templates faithfully but static (Flutter animates the CTA pill + image).
  Trigger: motion pass → add the keyframes.

## Coupons — built & deferred / known gaps

- [x] **Coupons.** `/dashboard/coupons` — full list (code · discount, lifecycle
  badge Live/Inactive/Expired/Exhausted, public/first-order chips, validity +
  redemption count, inline deactivate with confirm) mirroring the Flutter
  `MerchantCouponsPage`. Full-page editor `/new` + `[id]/edit` with a sticky
  live customer-card preview: code, title, description, PERCENT/FLAT discount
  (+ max-discount cap for PERCENT), min order, validity window, per-user limit,
  total cap, and Public / First-order-only / Active toggles. BFF `api/coupons`
  (GET list / POST) + `[id]` (PATCH/DELETE) → `/me/coupons-admin`. Coupon money
  is **rupees** (Decimal), not paise.
- [ ] **No single-coupon GET on the admin surface.** The backend exposes only
  `GET /me/coupons-admin` (list); there is no `GET /me/coupons-admin/:id`. The
  edit page therefore resolves an existing coupon by reading the (shop-scoped,
  small) list and finding by id — same source the Flutter editor sheet uses.
  Trigger: a dedicated detail endpoint lands → switch `getCoupon` to it.
- [ ] **Coupon redemption analytics.** The list shows `totalRedemptions` only.
  There's no per-coupon breakdown (who redeemed, when, discount given) — the
  backend `CouponRedemption` table exists but no merchant analytics endpoint.
  Trigger: a coupon-analytics endpoint → add a detail page like flash deals.
- [ ] **Date-only vs datetime.** The Flutter editor uses a date-only picker for
  valid-from/until; the web uses the shared `DateTimeField` (datetime-local) for
  consistency with the other marketing editors. Functionally equivalent — both
  send UTC ISO. Trigger: only revisit if the date-only granularity is required.

## Categories — built & deferred / known gaps

- [x] **Categories (merchant browse).** `/dashboard/categories` — read-only
  taxonomy grid (image/icon + name + product + subcategory counts) and
  `/dashboard/categories/[id]` drill-down with an **ancestor breadcrumb**, a
  **Subcategories** grid (each child links to its own category page), and a
  **Products** section (searchable, paginated → product detail). Mirrors the
  Flutter `CategoriesPage` + `CategoryProductsPage`, with nested-taxonomy
  navigation added. Children + breadcrumb are resolved from the tree
  (`findCategoryPath`); shared `CategoryCard`. BFF `api/categories/tree`
  (→ `/categories/tree?active=true`) + `api/categories/[id]`. Icon catalogue
  (`features/categories/icon-catalog.ts`) maps the 30 stored `iconName` strings
  to lucide equivalents.
- [ ] **Category taxonomy CRUD is admin-only.** Writes (`POST/PATCH/DELETE
  /categories`) are platform-admin (`requirePlatformAdmin`); the merchant
  section is intentionally read-only. Trigger: the `admin-taxonomy` nav screen
  ("Category taxonomy") → build the CRUD editor there, not here.

## Vendors & Customers (parties) — built & deferred / known gaps

- [x] **Vendors.** `/dashboard/vendors` (search, add/edit/delete with confirm,
  linked badge, txn/invoice counts) + `/dashboard/vendors/[id]` detail
  (header, contact rows, payable balance, net-purchased/stock-in/returns stats,
  ledger, recent bills, recent stock-in) + full-page `/new` + `[id]/edit`. BFF
  `api/vendors` (+ `[id]`, `[id]/overview`, `[id]/ledger`) → `/vendors`.
- [x] **Customers (parties).** `/dashboard/parties` (search, add/edit/delete,
  linked badge, **caution-balance chip**, challan/invoice counts) +
  `/dashboard/parties/[id]` detail (header, receivable balance, **caution
  deposit card**, net-billed/sales/returns stats, ledger, recent invoices,
  recent challans) + `/new` + `[id]/edit`. BFF `api/parties` (+ `[id]`,
  `[id]/overview`, `[id]/ledger`) → `/parties`. System parties (`isSystem`,
  e.g. Walk-in) are not editable.
- [x] **Shared contact editor + ledger.** `src/shared/ui/contact-editor.tsx`
  (name/contact/phone/email/GSTIN/PAN/address/city/PIN + GST-state select from
  `src/shared/india.ts`) and `src/shared/ui/ledger-list.tsx` +
  `src/shared/ledger.ts` are reused by both vendors and parties. The backend
  stays the authority for GSTIN/PAN/PIN formats; its field errors surface as-is.
- [ ] **Invite-to-Shopxy from vendor/party.** Flutter's row menu can send a
  linking invitation (`SendInvitePage` → `linkType: VENDOR|PARTY`). Web shows
  the resulting **Linked** badge (from `linkedUser`) but has no send/cancel
  action. Trigger: notifications/invitations feature on web → add an "Invite"
  action to the row menu + detail header.
- [ ] **Record payment.** Flutter's detail page has a "Record payment" FAB
  (`RecordPaymentSheet`, payments module). Not ported — web has no payments UI.
  Trigger: payments feature on web → add the FAB; the ledger already renders
  the resulting receipt rows.
- [ ] **Caution-deposit actions.** The party detail shows the caution **balance**
  read-only. The deposit / refund / set-off / forfeit / requests actions
  (`/parties/:id/caution/*`) are not wired — they're a separate module.
  Trigger: bring the caution flow to web → add the action card + history page.
- [ ] **Contact change-log.** Backend exposes `/:id/changes` (field-level audit)
  for both vendors and parties; not surfaced on web. Trigger: an "Activity /
  history" tab on the detail page.
- [ ] **Vendor/party doc links target placeholders.** Recent-bill rows link to
  `/dashboard/invoices/:id` and recent-challan rows to `/dashboard/challans/:id`,
  which currently land on the `[...section]` placeholder. Resolves automatically
  once the invoices/challans detail screens exist.

## Layout / shell debt

- [x] **Sidebar is route-based.** The dashboard area is a nested-route shell
  (`app/dashboard/layout.tsx` + link-based sidebar); deep-links + back/forward work.
- [x] **Unify `/account` into the sidebar shell.** Account management now lives
  at `/dashboard/profile` + `/dashboard/settings` inside the sidebar layout;
  `/account` is a permanent redirect to `/dashboard/profile`. The old
  `AppHeader` (`src/features/auth/components/app-header.tsx`) is now unused —
  delete it once nothing else references it.

## Profile & Settings — deferred / known gaps

- [ ] **Legal pages (Privacy / Terms).** Flutter Settings → About links to a
  `LegalPage` (privacy + terms copy). The web Settings About section currently
  shows only the app version. Trigger: legal content lands → add `/legal/privacy`
  + `/legal/terms` and About rows linking to them (register/consent can reuse).
- [ ] **Theme & language are placeholders.** Shown as "Coming soon" rows
  (parity with Flutter). Trigger: dark-mode / i18n support → make them live.
- [x] **Shop operations settings.** Built: `/dashboard/shop` (storefront, logo/
  banner, hours, vacation mode, policies, publish), `/dashboard/team` (members,
  invites, roles, full permission matrix), `/dashboard/payouts` (status). Linked
  from Settings → Shop operations.
- [x] **Custom-field definitions settings.** Built at `/dashboard/custom-fields`,
  linked from Settings → Inventory.
- [ ] **Payout KYC start wizard.** `/dashboard/payouts` is read-only status
  (`GET /linked-account`). The secure onboarding (PAN/bank capture → Razorpay
  Route, behind ROUTE_SPLIT_ENABLED, device-encrypted draft) stays in the mobile
  app; the web intentionally does not capture KYC. Trigger: a decision to bring
  KYC onboarding to web → build the wizard against `POST /linked-account`.
- [ ] **Custom-fields drag-reorder + icon picker.** Sections/definitions render
  in `sortOrder` but the web has no drag-reorder UI (`PATCH .../reorder` exists)
  and omits the per-field icon (the Flutter icon-name picker). Trigger: polish
  pass → add reorder handles + an icon picker.
- [ ] **Team: own-rights ceiling not pre-checked.** The permission matrix lets a
  non-owner pick any right; the backend rejects grants beyond the actor's own
  rights (`CANNOT_GRANT_BEYOND_OWN_RIGHTS`) and we surface that error. Trigger:
  nicer UX → disable un-grantable rows up front from the current user's perms.
- [ ] **App version is hard-coded** to `1.0.0` in `app/dashboard/settings`.
  Trigger: a build-time version constant → read it from there.

## Quality / infra debt (applies to both web apps)

- [ ] **No automated tests yet.** Add a vitest suite: auth schemas, `extractError`,
  the BFF route handlers, and the dashboard stats schema.
- [ ] **Enforcement tooling not wired.** Strict `tsconfig` flags
  (`noUncheckedIndexedAccess`, etc.), lint rules banning raw hex / arbitrary
  Tailwind values / inline numeric styles, CI (typecheck + lint + test + build),
  commitlint + husky. The conventions in CLAUDE.md are followed but not gated.

## Cross-app

- [ ] **Keep tokens + auth + CLAUDE.md in sync with `customer-web`** when changing
  shared bits (they are duplicated, not extracted).
