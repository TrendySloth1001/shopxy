# Customer-web UI/UX audit — live browser walkthrough

_2026-06-11 · tested in Chrome at 1456×817 (desktop) against the dev backend.
Ratings are /10 for the surface as a customer would experience it today.
Part 1 = public surfaces (guest). Part 2 (authed: checkout, orders, returns,
account, B2B) pending a login session in the test browser._

## Fixed during this audit (already live)

- **/search crashed the whole page** — `useSyncExternalStore` getSnapshot
  returned a fresh array per call (`use-recent-searches.ts`) → React
  infinite-loop guard. Fixed with raw-string-keyed snapshot cache.
- **One-word-per-line empty states everywhere** — `max-w-xs/sm/lg` resolve to
  the *spacing* scale in Tailwind v4 (4px/8px/16px) because the house theme
  names spacing tokens xs/sm/lg. Replaced with non-colliding container tokens
  `max-w-snug/narrow/panel` (320/384/512px) + theme entries.
- **Squeezed "Send quote request" dialog** — same root cause (`max-w-lg`).
- **Request-quote CTA unreachable** — bottom bar was `sm:relative` (end of a
  300-product list on desktop); now sticky on all sizes.
- **next/image rejected all remote product images** — no `images.remotePatterns`
  in next.config (Unsplash seed data). Allowed https hosts.
- **Add to cart / merchants page dead** — backend Prisma Decimals arrive as
  JSON strings; cart/checkout/merchants/catalog schemas demanded numbers.
  Shared `zNum` coercer + 28-field sweep + unit tests.
- **/dashboard removed** — notifications → `/notifications`, login lands on
  `/`, old URLs 307-redirect.
- **Back buttons** added to 25 sub-pages (history-aware, with fallbacks).
- **Header collapse flicker on scroll** (home) — hysteresis + rAF throttle.

---

## Part 1 — Public storefront (guest)

### Home `/` — 8/10
Works: full feed (hero, category pucks, trust strip, rails, flash deals,
collection banners), header collapse with compact search, images, endless scroll.
- **P1 — No cart access from home.** Home uses its own TopBar (bell + sign-in
  only); every other page's AppHeader has cart-with-badge, Orders, Wishlist.
  A guest who adds from a PDP and returns home loses the cart entry point.
  Unify or extend TopBar with the cart badge.
- P2 — During fast scroll there's a viewport-tall blank gap before lazy
  content paints (lazy-mount threshold too tight).
- P2 — Seed "Test Product …" cards ship no images → big gray tiles in the
  first rail (data hygiene, not code).

### Product detail `/p/[id]` — 5/10
Works: gallery/placeholder, stock chip ("Only 5 left"), seller card,
specs/reviews sections, share+wishlist floats, add-to-cart → toast + stepper
morph + Go-to-cart, guest cart persists, Buy now.
- **P1 — Mobile layout served to desktop.** Single column: the (often empty)
  gallery consumes the entire first viewport; name/price/CTA are below the
  fold. Desktop needs the standard two-column PDP (gallery left, buy box
  right).
- P1 — Ratings summary row layout: star-bucket counts are flushed to the far
  right edge with a hairline-thin (invisible at 0) distribution bar — looks
  broken whenever counts are 0; give the bars a track.
- P2 — Sticky bottom CTA bar stretches two full-width buttons across 1456px;
  cap to the content rail on desktop.
- P2 — Empty gallery placeholder shouldn't reserve a full square at desktop
  widths (cap height when imageless).

### Cart `/cart` — 8.5/10
Works: line card (image/shop chip/price/discount %), stepper with stock cap +
"Only N left", remove + UNDO toast, savings banner, bill summary, sticky total
card, checkout CTA, live header badge, fixed empty state.
- P2 — `mrp 100 / selling 500` seed rows show no MRP strikethrough (correct
  behavior, but seed data is inverted — worth a backend guard that MRP ≥
  selling at product save).

### Search `/search` — 7/10 (after the crash fix)
Works: URL-synced query, results with shop attribution + rating, count,
back arrow, empty/idle states with trending + recents.
- P1 — Result thumbnails render as gray boxes for many items (slim hit
  payload image vs dead seed URLs — verify `imageUrl` mapping in the hit
  mapper).
- P2 — Rows show no price context (MRP/discount) and no Add affordance;
  price sits far right, disconnected at wide widths — tighten row layout.
- P2 — The Filters chip opens controls the backend ignores (price/rating/
  stock were scope-cut server-side). Hide them until supported (separate
  task exists).

### Categories `/categories` — 6/10
Works: 2-row grid, subcategory counts, navigation.
- P1 — Category tiles are large empty gray rectangles — the tree endpoint's
  `imageUrl` isn't reaching the grid (home pucks show images for the same
  categories). Wire the image or drop the dead art area.

### Category products `/c/[slug]` — 8/10
Works: header w/ icon + count, subcategory chips (with images), sort pills,
grid with discount badges/price/MRP/rating, back to all categories.
- P2 — A few seed products' Unsplash URLs 404 → broken-image glyph; fallback
  to the canvas placeholder instead of the browser glyph.

### Shop profile `/shop/[slug]` — 7/10
Works: name/tagline/product count, sort pills, paginated grid, Home back link.
- P1 — Banner strip is a ~200px gray gradient void when the shop has no
  banner; logo is also an empty gray square. Collapse the banner when absent
  and letter-monogram the logo (home does this for category pucks).

### Deals `/deals` + Spotlights `/spotlights` — 5/10
Works: sections render, spotlight images load, offer label chip.
- **P1 — Spotlight cards are massively oversized** — a single card fills an
  entire desktop viewport (~650px tall image) on both pages; flash-deal
  content lands far below the fold on /deals. Cap spotlight banners to
  ~240–280px with overlay text.
- P2 — /deals "Brands in Spotlight" renders before the flash deals the page
  is named after; reorder.

### Login `/login` — 8/10
Clean centered form, show/hide password, register link.
- P2 — Subtitle still says "shops, invitations and invoice ledgers" (the old
  B2B-companion copy) — should say shopping/orders now.
- P2 — No "forgot password" affordance (backend support unknown — flag for
  roadmap).

### Banners `/banners/[id]` — not ratable
No banner links exist in the current home feed data, so the page couldn't be
reached organically; needs seed data with a live campaign.

---

## Part 2 — Authed surfaces (tested live as nkumawat1010)

### Additional fixes applied during Part 2
- **Merchants page hydration error** — the whole `MerchantCard` was a `<Link>`
  with the Catalog/Invoices/Caution/Quotes quick-links nested inside (invalid
  `<a>`-in-`<a>`, React hydration error in console). Card is now a div; banner
  + title carry the catalog link.

### Checkout `/checkout` — 8.5/10
Works: guest cart merged into account cart on login (4 items, 4 shops),
multi-vendor notice ("we'll create 4 separate orders"), saved address card
with DEFAULT chip + Change, delivery estimate, per-shop item groups with
subtotals, coupon field, COD/Pay-Online radios, savings line, sticky total
card. The ≥₹500 confirm dialog quotes the true grand total with calm copy.
- **P1 — Line-item thumbnails are broken** (alt-text boxes) for products whose
  images load fine on category pages — checkout's thumbnail src construction
  is wrong (likely prefixing `/api/media` onto absolute URLs). Same broken
  thumbs carry into the order-detail page.
- P2 — Right-hand "Total payable" card shows only the total; repeat the bill
  breakdown (items/savings/coupon/wallet) there like the cart page does.

### Orders `/orders` + `/orders/[id]` — 9/10
Works: status tabs with counts (All 14 / Pending / Confirmed / Cancelled),
aggregate chips ("0/4 CONFIRMED"), totals, dates; detail shows delivery
address, per-shop packages with status chips, per-package Cancel with the new
styled confirm modal → CANCELLED chip + success snackbar without touching the
other shops. Placed a real COD order (#841, ₹27,738) and cancelled one slice
live — whole loop worked.
- P2 — Same broken item thumbnails as checkout.
- P2 — Cancelled package keeps showing "PENDING→" timeline area blank; a
  "cancelled on <date>" line would close the story.

### Wishlist — 8/10. Clean row card (image, MRP/discount, View/Remove).
### Account hub `/account` — 9/10. Tidy Shopping/Account sections, all links live.
### Wallet — 8/10. Balance hero + empty ledger state. (₹0 — refund from the
cancelled COD slice is correctly zero since nothing was paid.)
### Notifications `/notifications` — 8/10
Typed icons, unread dots, quote amounts in body, Mark-all-read, deep links.
- P2 — Bell badge (16) doesn't decrement until Mark all read is pressed;
  consider auto-marking visible items read.

### Merchants hub `/merchants` — 8/10 (after hydration fix)
Banner card, role chip, invoice count + last-invoice line, quick links.
- P2 — Single card stretches the full grid column width alone; cap card width
  or show a 2-up grid on desktop.

### Caution `/merchants/party/[id]/caution` — 8.5/10
Balance hero with deposited split, Request deposit CTA, request list with
Cancelled/Approved+Held chips, receipt-numbered history ledger. (Pay-online
button appears only on PENDING requests — none existed during the audit; flow
was verified end-to-end earlier via API.)

### Quotations list + request-quote — 9/10 (after today's fixes)
List: status chips (Requested/Accepted/Awaiting you), per-quote totals en-IN
formatted. Request-quote: catalogue search + category count chips, Add per
row, **sticky selection bar reachable without scrolling**, and the send dialog
now renders at proper 512px width with note field.
- P2 — Send dialog sits low on the screen; vertically center it.
- P2 — "Awaiting you" quotes deserve a highlighted Accept/Decline affordance
  right on the list row.

## Remediation pass (2026-06-11, same day) — all audit findings fixed

Verified live in the browser after the fixes:
- **PDP**: two-column desktop layout (sticky gallery left, buy box right —
  title/price/CTAs above the fold, content-width buttons, seller card in
  column); sticky bottom bar mobile-only; empty gallery capped at 420px;
  ratings histogram has visible tracks.
- **Thumbnails**: new `mediaSrc()` helper (src/shared/media.ts) — absolute
  URLs pass through, relative keys proxy via /api/media. Applied across cart,
  checkout, order detail, search rows, catalog cards, request-quote; dead
  URLs fall back to a neutral placeholder (no browser glyph).
- **Home top bar**: cart icon + live badge beside the bell (expanded and
  collapsed states).
- **Deals/Spotlights**: banners capped (21/6, ≤240px) in a 1-col/2-col grid;
  flash deals ordered first.
- **Categories grid**: images wired through mediaSrc with tinted monogram
  fallback; tile height clamped.
- **Shop profile**: bannerless shops no longer show a gray void; monogram
  logo fallback.
- **Search**: dead filter controls (price/rating/stock — backend unsupported)
  hidden; thumbnails fixed; price kept attached to the row. (MRP strikethrough
  deferred: search hits don't carry mrp.)
- **Checkout**: right-hand card now shows the full bill breakdown above the
  total.
- **Orders**: cancelled packages show "Cancelled on <date>".
- **Notifications**: opening the inbox auto-clears the bell badge after ~1s.
- **Merchants hub**: responsive 1/2/3-col grid; hydration error fixed
  (nested-link card restructured).
- **Quotations**: "Awaiting you" rows carry an outlined Review button;
  request-quote confirm dialog centered with dimmed backdrop.
- **Login**: subtitle now shopping-first.

Still open (data/backend, not UI): dead Unsplash seed URLs; seed rows with
mrp < sellingPrice; backend search filters (separate task); /banners needs a
live campaign in seed data to exercise.

## Verdict
Buy path (home → PDP → cart → checkout → order → cancel) is functional
end-to-end with good feedback patterns. The two biggest remaining UX debts are
the **desktop PDP layout** and **checkout/order thumbnails**; everything else
is polish-grade.
