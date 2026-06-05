# PENDING.md — merchant-web

Deferred wiring and known stubs. **Read this before implementing a new feature**
— when you build something here, check whether it unblocks an item below and
wire it up. **When you stub, defer, or simplify something, add a row here** with
where it lives and what triggers finishing it.

Format: `[ ]` open · `[x]` done. "Trigger" = the feature whose arrival means
this should be revisited.

## Deferred wiring (stubbed — connect when the trigger lands)

- [ ] **Sidebar nav → real screens.** `Products` and `Orders` are built; the
  rest still land on the `/dashboard/[...section]` placeholder. Trigger: building
  each remaining section (invoices, quotations, challans, stock-adjustments,
  returns, reports, analytics, vendors, parties, categories, coupons, promotions,
  flash-deals, spotlight, carousels, shop) — add `app/dashboard/<section>/…`.
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
- [ ] **Custom-field definitions UI.** The product editor reads shop-wide
  definitions (`GET /custom-fields`) but there's no web screen to create/edit the
  definitions themselves (the POST/PATCH endpoints exist).
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
- [ ] **Shop operations settings.** Flutter Settings has a "Shop operations"
  entry (hours, vacation mode, payouts, KYC, team) behind the relevant
  capabilities. Trigger: shop / payouts / team web features → add the section.
- [ ] **Custom-field definitions settings.** Flutter Settings → Inventory opens
  the custom-fields editor (the product editor already reads the definitions).
  Trigger: build the definitions UI (see the Products gap above) → link it here.
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
