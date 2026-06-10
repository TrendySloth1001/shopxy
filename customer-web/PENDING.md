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
- [ ] **Home destination pages are stubs.** Product tiles/banners/category pucks
  link to `/product/[id]`, `/search?q=`, `/shop/[slug]`, `/category/[slug]`,
  `/collection/[slug]`, `/banner/[id]` — **none of these pages exist yet** so
  taps 404. Build them (PDP first) and the home already links in. Helpers:
  `productHref` (product-tile), `searchHref` (product-carousel), `slideHref`
  (hero-slide).
- [ ] **Top-bar delivery address + wallet badge omitted.** The Flutter top bar
  shows the default delivery address and a pending-online-payment wallet badge;
  both need addresses/orders features (not on web yet). The location row links
  to `/account` and the wallet badge is dropped until those land.
- [ ] **Pending-invite home callout not ported.** The Flutter home shows a
  pending-invitation card at the top of the feed; customer-web has no invites
  surface yet (see notifications note). Add it to the home prelude when the
  invitations accept/decline surface is built.
- [ ] **Hero/spotlight are single-card (no auto-advance carousel).** The feed
  composer emits one banner/spotlight per block (as the mobile app does), so the
  multi-slide auto-advancing carousel + Ken-Burns/shimmer animations weren't
  needed. Add them if a multi-slide hero placement is introduced. Trust strip is
  the static row (mobile's rotating-carousel variant not ported).
- [ ] **Home / dashboard (shops, invitations, ledgers) still unbuilt.** The
  marketplace home above is the public storefront; the signed-in
  shops/invitations/invoice-ledger surfaces remain to be built.
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

## Quality / infra debt (applies to both web apps)

- [x] **Vitest suite + CI wired.** `npm test` covers the auth schemas, shared
  formatters, and the home mapper/composer/format (`src/features/home/home.test.ts`).
  The `customer-web` CI job runs lint+typecheck+test+build. Still worth adding:
  BFF route-handler tests and `extractError`.
- [ ] **Enforcement tooling not wired.** Strict `tsconfig` flags, lint rules
  banning raw hex / arbitrary Tailwind values / inline numeric styles, CI,
  commitlint + husky. CLAUDE.md conventions are followed but not gated.

## Cross-app

- [ ] **Keep tokens + auth + CLAUDE.md in sync with `merchant-web`** when changing
  shared bits (they are duplicated, not extracted). Note merchant-only token
  accents (flashDeal/whatsapp) do not belong here. customer-web now also defines
  a `promo` token group (flash-deal peach/orange + spotlight yellow) used by the
  home feed — added to both `tokens.ts` and the `@theme` in `globals.css`.
