# PENDING.md — merchant-web

Deferred wiring and known stubs. **Read this before implementing a new feature**
— when you build something here, check whether it unblocks an item below and
wire it up. **When you stub, defer, or simplify something, add a row here** with
where it lives and what triggers finishing it.

Format: `[ ]` open · `[x]` done. "Trigger" = the feature whose arrival means
this should be revisited.

## Deferred wiring (stubbed — connect when the trigger lands)

- [ ] **Sidebar nav → real screens.** `src/features/dashboard/sidebar.tsx`
  buttons only set the active section; non-dashboard keys render a placeholder
  in `src/app/dashboard/page.tsx`. Trigger: building each section (products,
  orders, invoices, quotations, challans, stock-adjustments, returns, reports,
  analytics, vendors, parties, categories, coupons, promotions, flash-deals,
  spotlight, carousels, shop) — replace the placeholder with the real screen.
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

## Layout / shell debt

- [ ] **Unify `/account` into the sidebar shell.** `/account` still uses the old
  top `AppHeader` (`src/features/auth/components/app-header.tsx`), while
  `/dashboard` uses the sidebar. Move account under the sidebar layout, and make
  the sidebar **Profile/Account** button actually navigate to `/account`
  (currently a no-op placeholder button).
- [ ] **Sidebar buttons are local state, not routes.** Consider real routes
  (`/dashboard/products` …) so deep links + back/forward work, once sections exist.

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
