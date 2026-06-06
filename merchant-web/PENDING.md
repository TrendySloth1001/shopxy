# PENDING.md — merchant-web

Deferred wiring and known stubs. **Read this before implementing a new feature**
— when you build something here, check whether it unblocks an item below and
wire it up. **When you stub, defer, or simplify something, add a row here** with
where it lives and what triggers finishing it.

Format: `[ ]` open · `[x]` done. "Trigger" = the feature whose arrival means
this should be revisited.

## Deferred wiring (stubbed — connect when the trigger lands)

- [x] **Sidebar nav → real screens.** Every merchant nav destination is built:
  `Products`, `Orders`, `Shop`, `My Carousels`, `Flash deals`, `Brand spotlight`,
  `Promotions`, `Coupons`, `Categories`, `Vendors`, `Customers` (parties),
  `Invoices`, `Quotations`, `Challans`, `Stock adjustments`, `Returns`, `Reports`,
  `Analytics` (+ Profile / Settings / Team / Payouts / Custom fields). The
  `/dashboard/[...section]` placeholder now only catches unbuilt **Platform admin**
  tools (banner manager, taxonomy, approvals, collections, bank offers, shop
  verification).
- [x] **Dashboard row tap-through.** `DraftRow` now links to its invoice detail
  (`/dashboard/invoices/:id`) and `ActivityRow` links to its source doc
  (`tx.sourceType` `INVOICE`→invoice, `CHALLAN`→challan, via `tx.sourceId`); rows
  without a linkable source stay plain. In `src/features/dashboard/dashboard-home.tsx`.
- [x] **Dashboard pending-invite callout.** Built — `PendingInviteCallout` in
  `dashboard-home.tsx` fetches incoming invitations and, when any are PENDING,
  shows a brand callout linking to the notifications Invites tab.
- [ ] **Payout-setup nudge.** Flutter nudges Razorpay-Route payout onboarding
  once per session (behind ROUTE_SPLIT_ENABLED). Trigger: payouts / linked-account
  feature on web → add the nudge to the dashboard.
- [x] **`dashboard:view` no-access state.** Resolved — `SectionGuard`
  (`src/features/auth/components/section-guard.tsx`) maps the route to its
  permission area and renders `NoAccessView` when the member can't view it.
  Sidebar items lock too, and write routes (`/new`, `/edit`) require `:manage`.
- [x] **Notification bell.** Built — a **Notifications** sidebar item (Bell) with a
  live unread badge (`NotificationsProvider` polls `/notifications/unread-count`
  every 60s + on focus) and a full `/dashboard/notifications` page (per-kind icons,
  relative time, mark-read on tap + deep-link by kind, mark-all-read, paginated).
  The merchant shell has no top bar, so the bell lives in the sidebar nav.

## Products — deferred / known gaps

- [x] **Stock in / Stock out.** Built — the product detail page has "Stock in"
  (purchase) and "Stock out" (sale) actions (`src/features/stock/stock-sheet.tsx`)
  that POST `/stock` and create a draft invoice. Supplier (`GET /stock/suppliers`)
  and customer (`GET /parties`) lists are pre-loaded into dropdowns (select, not
  search). Gated by `stock:manage` via `MaybeLocked`. Mirrors the Flutter
  `StockBottomSheet`. Free-text supplier autocomplete (history) was NOT ported —
  web uses the vendor dropdown only (the backend create only takes `vendorId`).
- [x] **Variants don't re-read on merchant detail/edit.** Fixed —
  `getProductById` (`backend/src/modules/products/products.service.ts`) now
  includes the `variants` relation (mirrors the list projection), so
  `GET /products/:id` returns them and the edit form's Variants section
  re-hydrates on reload.
- [x] **Custom-field definitions UI.** Built at `/dashboard/custom-fields`
  (sections + definitions CRUD, templates). See the Shop/Settings section below
  for the remaining custom-field gaps (drag-reorder, icon picker).
- [ ] **OCR / barcode-scan helpers** from the Flutter add/edit (camera scan to
  prefill SKU/barcode) are not ported — native-camera features.
- [x] **List filters are in the URL.** Products search/category/sort/low/out/page
  now read from and mirror to query params (Suspense-wrapped `useSearchParams` +
  `router.replace`), so the view deep-links and survives refresh.

## Orders — deferred / known gaps

- [x] **Restock-from-order flow.** Flutter lets the merchant tap a short line on a
  pending order to open a stock-in sheet, then confirm the draft inline so the
  shortfall clears without leaving the order. On web the shortfall banner + per-
  line stock chips are informational only. Trigger: stock-adjustments / stock-in
  + invoices web features land → wire the restock action on the detail page.
- [x] **Shipping events: Update-shipping UI added.** The order detail renders the event
  timeline (`GET /orders/:id` → `events`), but there's no UI to *post* a
  milestone. Backend supports `POST /orders/:id/events`
  (PACKED/SHIPPED/OUT_FOR_DELIVERY/DELIVERED/RETURNED + courier/awb/eta). Trigger:
  fulfilment UX → add an "Update shipping" action.
- [x] **Open-invoice CTA targets a placeholder.** Resolved — the invoices detail
  screen (`/dashboard/invoices/:id`) now exists, so the confirmed-order CTA opens it.
- [x] **`orders:view` no-access state.** Resolved by the same `SectionGuard` —
  the orders area now renders `NoAccessView` for members without `orders:view`.
- [x] **Row-level write actions are now gated.** Section + create-button
  (`/new`) gating is done via `SectionGuard` / `MaybeLocked`; per-row Edit/Delete
  and other in-list write controls still rely on the backend 403 rather than a
  client-side lock. Trigger: extend `MaybeLocked` to row actions for parity with
  the Flutter app.

## Operations — Invoices / Quotations / Challans (built & deferred)

- [x] **Invoices.** `/dashboard/invoices` (search, Sales/Purchases tabs, status +
  document-type filters, per-row PDF) + `/dashboard/invoices/[id]` detail
  (counterparty block, items, GST totals split IGST vs CGST+SGST, round-off,
  received/outstanding + payments when CONFIRMED; actions: Edit draft, PDF,
  Mark-as-paid, Convert estimate→invoice, Confirm/Cancel draft, Delete) +
  full-page editor `/new` & `[id]/edit` (SALE/PURCHASE, saved party/vendor picker
  or walk-in fields with place-of-supply, product line items with qty/rate/GST,
  header discount, document type, live totals, Save-draft / Save-&-confirm). BFF
  `api/invoices` (+ `[id]`, `[id]/status`, `[id]/convert`, `[id]/pdf`) → `/invoices`.
  Invoice money is **rupees** (Decimal). The editor totals are a live preview; the
  backend recomputes the authoritative GST split on save.
- [x] **Quotations.** `/dashboard/quotations` (status tabs) +
  `/dashboard/quotations/[id]` detail (status meta, items, totals, note, invoice
  link once accepted; actions: PDF, Cancel a PENDING quote, Decline / Price-&-send
  a customer's REQUESTED quote) + `/new` (build a bucket → pick a linked customer →
  send) and `[id]/respond` (price a requested quote). BFF `api/quotations` (+ `[id]`,
  `[id]/respond`, `[id]/cancel`, `[id]/decline-request`, `[id]/pdf`) → `/quotations`.
  "Accept" is customer-driven (spawns a confirmed invoice server-side); the merchant
  side only shows the resulting invoice link.
- [x] **Challans.** `/dashboard/challans` (search + status filter) +
  `/dashboard/challans/[id]` detail (party/meta, qty-only items; actions: Cancel a
  PENDING challan, Convert-to-invoice → draft sale invoice) + `/new` (saved customer
  or manual party, qty-only product lines). BFF `api/challans` (+ `[id]`,
  `[id]/cancel`, `[id]/convert`) → `/challans`.
- [x] **Shared pickers + PDF proxy.** `src/shared/ui/picker-modal.tsx` is a generic
  debounced search picker reused for product / party / vendor selection across all
  three editors. `src/server/pdf.ts` (`streamPdf`) passes the backend-rendered PDF
  through the BFF as binary (the JSON `proxy()` can't); the invoice/quotation "PDF"
  buttons open it in a new tab (download / print / save).
- [x] **Stock adjustments.** `/dashboard/stock-adjustments` (list with reason
  badge + direction) + `/new` editor (reason chips DAMAGE/EXPIRED/SHRINKAGE/
  RECOUNT/OPENING, direction toggle for RECOUNT/OPENING, product qty items, note)
  + `/dashboard/stock-adjustments/[id]` detail (items with signed qty + a
  **Reverse** action that undoes the ledger movement — backend supports it even
  though Flutter doesn't expose it). BFF `api/stock-adjustments` (+ `[id]`,
  `[id]/reverse`) → `/stock-adjustments`. Qty-only like Flutter (no unit-cost
  field). The standalone **stock ledger feed** (`GET /stock`) isn't surfaced yet
  — trigger: a "Stock ledger" view if the movement history is needed.
- [x] **Returns.** `/dashboard/returns` (status tabs Open/Approved/Received/
  Refunded/All) + `/dashboard/returns/[id]` detail (customer + order, items with
  reason chips + per-item refund, event timeline, buyer/your notes, refund
  confirmation) with the full workflow action bar: Approve / Reject (REQUESTED),
  Mark picked-up (APPROVED), Mark received (APPROVED/PICKED_UP), **Refund**
  (credits the wallet + restocks). Customer-initiated only (no merchant create).
  BFF `api/returns` (+ `[id]`, `approve/reject/picked-up/received/refund`) →
  `/orders/returns` (orders area). Product thumbnails omitted (text-first rows).
- [x] **Reports.** `/dashboard/reports` — Sales / Purchases / GST / P&L tabs with
  a date-range control (From/To + This-month / Last-30-days / This-FY presets).
  Sales & Purchases: headline total, daily bar series, top products + top
  customers/vendors leader bars. GST: output/input/net-payable + rate-wise
  breakdown. P&L: net profit + margin and a revenue→COGS→gross→writeoffs→net
  ledger. BFF `api/reports/{sales,purchases,gst,pnl}` → `/reports/*`. No
  PDF/CSV export (the Flutter app has none either).
- [x] **Analytics.** `/dashboard/analytics` — a full engagement dashboard over a
  date range: KPI strip (impressions/taps/views/ATC/purchases/wishlist/CTR/CVR),
  a **conversion funnel** with step drop-off % + leak KPIs (cart abandonment,
  browse→buy, wishlist→buy), an **engagement-over-time line** (metric toggle), a
  rule-based **"what to act on"** insights panel, **hidden-gems / needs-attention**
  opportunity lists, **leaderboard bars**, a **day×hour purchase heatmap**, a
  **new-vs-returning customers / repeat-rate** block, a **stock-forecast** (days
  of cover from 30-day velocity × on-hand stock), and the sortable per-product
  table. Distinct from Reports (money). Charts are dependency-free
  (`src/shared/ui/charts.tsx` `LineChart`, CSS bars, SVG). BFF
  `api/analytics/{products,heatmap,customers}` → `/me/analytics/*`.
  Backend (cross-app): added `daily[]` to `/me/analytics/products` and new
  `/me/analytics/heatmap` + `/me/analytics/customers` endpoints.
  Remaining backend-only ideas not built: hour/day heatmap already done;
  seasonality-aware demand forecasting and deeper retention cohorts still open.
- [x] **Reports trend + run-rate.** Sales/Purchases now render a trend line
  (+ 7-day moving average) and a "≈ ₹X/day, ~₹Y/30 days at this pace" run-rate
  line (a pace estimate, not a forecast). Shared `LineChart`.
- [x] **Shimmer loading everywhere.** Added `src/shared/ui/skeleton.tsx`
  (`Skeleton`, `ListRowsSkeleton`, `CardsSkeleton`, `DetailSkeleton`,
  `FormSkeleton` — `animate-pulse` over `bg-hairline` at token radii) and
  replaced every plain "Loading…" across all dashboard list/detail/form/settings
  pages with a layout-matched skeleton. Remaining plain text loaders are the
  app-level auth gate (`RequireAuth`) and two inline sub-component loaders
  (carousel slide editor, custom-fields editor) — not full pages.
- [ ] **Native-only invoice extras not ported.** The Flutter editor has a
  barcode/QR scan-to-add and per-row line discount; the detail has a "Share via
  WhatsApp" deep link and native file download/share. On web: no scanner, no
  per-line discount field (header discount only — matches the Flutter row, which
  also edits qty/rate/GST only), and PDF opens in a browser tab instead of native
  share. Trigger: revisit if these are needed.
- [x] **Challan convert override.** `Convert to invoice` now opens a modal where
  the merchant can set an optional header discount + note (forwarded to the
  convert endpoint) before creating the draft.
- [x] **Estimate/Proforma editor entry.** The invoices list has "Estimate" and
  "Proforma" entry buttons → `/dashboard/invoices/new?doc=ESTIMATE|PROFORMA`,
  which pre-selects the document type in the editor (`initialDocumentType`).
- [~] **Native-only invoice extras** (barcode scan-to-add, per-line discount,
  native WhatsApp/file share) stay deferred — native-only, like the OCR helpers.

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
- [x] **Carousel slide reorder.** The carousel detail slide list has up/down
  reorder buttons that renumber `sortOrder` by position and persist the changed
  slides (handles legacy all-zero sortOrders). (Full drag-and-drop deferred —
  up/down is robust and accessible.)
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
- [x] **No single-coupon GET on the admin surface.** Added
  `GET /me/coupons-admin/:id`; `getCoupon` now uses it instead of scanning the list.
- [x] **Coupon redemption analytics.** Added `GET /me/coupons-admin/:id/redemptions`
  (who redeemed, when, discount given) + a per-coupon redemptions modal opened from
  the coupons list.
- [x] **Date-only vs datetime.** Web already uses the shared `DateTimeField`
  (datetime-local); no change needed (the note was about the Flutter date-only picker).

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
- [x] **Invite-to-Shopxy from vendor/party.** The detail header has an
  `InviteControl` (`features/invitations/`): an **Invite** button (disabled
  until the contact has an email) opens a modal (prefilled email + optional
  message) → `POST /invitations` with `linkType` + `partyId`/`vendorId`. While
  pending it shows an **Invited** chip with a cancel (✕ → `DELETE
  /invitations/:id`); once accepted the **Linked** badge takes over. BFF
  `api/invitations` (GET `/invitations/outgoing`, POST) + `[id]` (DELETE).
  Minor gap: invite status chips aren't shown on the list rows yet (detail
  header only) — add later if the list needs at-a-glance link status.
- [x] **Record payment.** Built (`src/features/payments/`): the party detail header
  has a **Record payment** button (RECEIPT → party) and the vendor detail header a
  **Record payment** button (PAYMENT → vendor), both opening `RecordPaymentModal`
  (amount, mode, reference, date, note) → `POST /payments`; the balance/ledger
  refresh on success. The invoice detail also has **Mark as paid** (allocates the
  receipt/payment to that invoice, capped at the outstanding). BFF `api/payments`
  (GET list / POST) + `[id]` (DELETE soft-void). Not yet surfaced: a void-payment
  button on the payment rows, and an on-account payments list on the contact page.
- [x] **Caution-deposit actions.** Party detail has an actionable caution card
  (`features/caution/caution-card.tsx`): **Add / Refund / Set off / Forfeit**
  via modals (refund/set-off/forfeit capped at the held balance; set-off picks a
  confirmed sale invoice; forfeit carries a GST-treatment flag), plus
  **History** (`/dashboard/parties/[id]/caution`) and **Requests**. A successful
  action refreshes the party balance. Shop-wide **Caution requests** inbox at
  `/dashboard/caution-requests` (approve → deposit, decline with reason). BFF
  under `api/parties/[id]/caution*` + `api/caution-requests` → `/parties/:id/
  caution*` and `/caution-requests`. (Set-off invoice list is drawn from the
  overview's recent confirmed sale invoices; the backend enforces the
  per-invoice outstanding cap and surfaces its error.)
- [x] **Contact change-log.** Built — an "Activity & history" panel on the party
  and vendor detail pages lazy-loads the field-level audit (`/:id/changes`) via a
  shared `ContactChangesSection`.
- [x] **Vendor/party doc links target placeholders.** Resolved — the invoices and
  challans detail screens now exist, so recent-bill / recent-challan rows open them.

## Layout / shell debt

- [x] **Sidebar is route-based.** The dashboard area is a nested-route shell
  (`app/dashboard/layout.tsx` + link-based sidebar); deep-links + back/forward work.
- [x] **Unify `/account` into the sidebar shell.** Account management now lives
  at `/dashboard/profile` + `/dashboard/settings` inside the sidebar layout;
  `/account` is a permanent redirect to `/dashboard/profile`. The old
  `AppHeader` (`src/features/auth/components/app-header.tsx`) is now unused —
  delete it once nothing else references it.

## Profile & Settings — deferred / known gaps

- [x] **Legal pages (Privacy / Terms).** Built public pages at `/legal/privacy`
  and `/legal/terms` (shared `LegalDoc`), linked from Settings → About and the
  register-form consent checkboxes.
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
- [x] **Team: own-rights ceiling pre-checked.** The permission matrix lets a
  non-owner pick any right; the backend rejects grants beyond the actor's own
  rights (`CANNOT_GRANT_BEYOND_OWN_RIGHTS`) and we surface that error. Trigger:
  nicer UX → disable un-grantable rows up front from the current user's perms.
- [x] **App version** now reads `NEXT_PUBLIC_APP_VERSION` (from package.json via
  next.config) in `app/dashboard/settings` instead of a hard-coded `1.0.0`.
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
