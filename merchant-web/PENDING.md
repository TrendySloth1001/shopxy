# PENDING — merchant-web deferred / stubbed wiring

Track stubbed, deferred, or simplified wiring here so it isn't forgotten.
Tick items off when the dependent feature lands.

## Dashboard (full redesign — Jun 2026)

The dashboard was rebuilt from scratch into a money + action overview with a
period switcher, KPI hero row, trend chart, action center, insights, operations
strip, smart alerts, and an onboarding checklist. **Stock Pulse removed.**

- Backend: `GET /dashboard/stats?period=today|week|month`
  (`backend/src/modules/dashboard/`). Money sections (`kpis`, `trend`,
  `insights`, `operations.gstMtd`) are gated by `reports:view`; the till tile
  needs an open shift.
- Web: `src/features/dashboard/dashboard-home.tsx` orchestrates components under
  `src/features/dashboard/components/`; reuses `shared/ui/charts.tsx` `LineChart`.

Deferred / simplified:

- [ ] **Flutter merchant app parity.** `frontend/` reads the same endpoint and
  ignores the new fields. Port the new sections to
  `frontend/lib/features/dashboard/` to match the web.
- [ ] **Backend perf split.** A full load is ~25–30 indexed parallel queries and
  period-independent sections (receivables, payables, GST, inventory) are
  recomputed on every period switch. If it feels heavy, split into a static
  endpoint + a `?period` series endpoint, or add a short Redis cache.
- [x] **KPI drill-down drawers.** Each hero KPI card now opens a right-side
  `SideSheet` instead of navigating: Sales → products sold (name/SKU filter,
  `/reports/sold-products`), Net profit → the traced P&L statement
  (`/reports/pnl`), Receivables/Payables → per-debtor/creditor accounts, each
  expandable to the confirmed documents behind the balance. New backend:
  `GET /dashboard/receivables` + `/dashboard/payables` (`reports:view`-gated,
  `dashboard.service.ts` `receivablesBreakdown`/`payablesBreakdown`); web:
  `features/dashboard/components/kpi-drawers.tsx` + `drilldown.ts`.
- [ ] **Receivables / payables ageing + per-invoice allocation.** No `dueDate` /
  payment-terms column on `Invoice`, and payments are recorded at the
  party/vendor level (not allocated to a specific invoice). So the drill-down
  drawers show the party-level balance + the list of confirmed documents, but
  **no overdue ageing** (0–30 / 31–60 / 60+) and no per-invoice balance-due. Add
  ageing/allocation once invoice due-dates + payment allocation exist.
- [ ] **Smart-alert heuristics.** Sales-drop threshold (−25%), GST-due window
  (14th→20th of month), low-stock and till-open rules live in
  `dashboard.service.ts buildAlerts`. Tune against real merchant behaviour; GST
  due date assumes monthly GSTR-3B (not QRMP).
- [ ] **Profit delta cost.** `kpis.profit` calls `reportsService.pnl` twice
  (current + previous window) for its delta — the heaviest part of the load.
  Replace with a lean prior-window query if needed.

- [x] **Google SSO ("Continue with Google").** Shipped (Jul 2026) — but as a
  client-side ID-token flow (Google Identity Services `prompt()` from our own
  button, verified server-side via `google-auth-library`), NOT the
  authorise-code redirect this note originally sketched. No client secret
  needed. New accounts get role OWNER, shopless, and must set a 4-6 digit
  recovery PIN (`/onboarding/recovery-pin`) before continuing — the only
  fallback since Google accounts have no password. Returning users can sign
  in with that PIN at `/login/recovery-pin` if Google itself is ever
  unreachable. Set `NEXT_PUBLIC_GOOGLE_CLIENT_ID` (web) to enable; the button
  renders nothing if unset. Not yet added to the register form.
  - [ ] `RecoveryPinLoginForm` doesn't collect a TOTP code — an account with
    both a recovery PIN and 2FA enabled hitting that exact path is a narrow
    edge case not covered yet (backend supports it; the form doesn't ask).
  - [ ] customer-web / customer Flutter app don't have Google sign-in
    (merchant-only per the original ask). The Flutter merchant app gets the
    same flow separately — check `frontend/PENDING.md` (if present) for its
    status.

## HSN/SAC rate master (Jul 2026)

The GST rate is no longer typed. The merchant classifies the product — one
input — and the rate is derived: `hsn_codes` holds codes and rates, the
translatable copy catalogues hold the words merchants search by, and the tax
field on the product form is a **readout** with an explicit manual escape
hatch. Backend: `backend/src/modules/hsn/`. Web:
`features/products/components/hsn-field.tsx` + `gst-rate-field.tsx`.

Deferred / open:

- [x] **Tariff *structure* imported.** `hsn.master.json` now holds **6,999**
  entries and the boot log reads `source: "imported"` instead of the
  provisional warning. Directory = the WCO Harmonized System
  (`github.com/datasets/harmonized-system`, **ODC-PDDL-1.0 / public domain**,
  6,939 rows, official chapter → heading → sub-heading wording), merged with our
  375 curated entries appended last so reviewed wording wins on codes a human
  checked. Deep codes bill through inheritance — `620520` resolves 5% via
  `6205` — so the added rows are usable, not just browsable.
- [ ] **Tariff *rates* are still ours, and this is the remaining gap.** Only
  **297** of the 6,999 rows can price a line; the other 6,702 are
  `isRatable: false` navigation rows, which is correct (a code with no notified
  rate must not invent one) but means coverage is 297 headings wide. Those 297
  are hand-derived from Notification 9/2025-CT(Rate), **not** an official
  machine-readable download.
  Both government sources refuse automation *by design* and must not be worked
  around: `services.gst.gov.in` rejects non-browser requests at the WAF, and
  NIC's e-invoice HSN master (`einvoice1.gst.gov.in/Others/MasterCodes`) is
  CAPTCHA-gated. So this needs a **human download**: fetch the rate schedule /
  CBIC rate-finder export, then
  `npm run hsn:import -- --directory <codes> --rates <rates>` and commit the
  diff. Watch `superseded` in the seed output — a non-zero count means a rate
  moved under existing products.
- [x] **"My HSN codes" screen.** Web: `dashboard/hsn-codes` (nav → Manage).
  Flutter: `products/presentation/pages/hsn_codes_page.dart` (Menu → Manage).
  Lists saved shortcuts with their **live** rate, flags ones whose code no
  longer resolves, and allows re-pointing (upsert on the merchant's own
  wording) or removal. Rate overrides are a second section, gated on
  `shop:manage`, showing the platform rate beside the merchant's so the
  departure is stated rather than silently entered.
  - Also closed two defects found while building it: the web `via` enum was
    missing `"TEXT"`, so every BM25 suggestion failed zod and the array was
    dropped to `[]`; and `/hsn` is mounted outside `mountMerchant`, which left
    the shortcut/override **writes** ungated — a Cashier could set a rate
    override. Guards now live in `hsn.routes.ts` with three regression tests.
- [ ] **Overrides can't be edited or back-dated from the UI.** The screen
  creates and soft-deletes; `effectiveFrom` always defaults to today and cess
  isn't exposed. The backend accepts both, so this is a form gap, not a
  contract one. Editing is deliberately absent: re-creating leaves a record of
  what the position was, editing in place would rewrite history.
- [ ] **Rate-change notification.** Rates apply automatically on their
  effective date (correct — a Council revision is not optional), but nothing
  tells the merchant it happened. Needs a notification listing the affected
  products, ideally sent ahead of the effective date.
- [ ] **Reconciliation report.** `products.tax_source` makes divergence
  queryable ("billing at a rate the code doesn't support"), and
  `invoice_items.hsn_revision` bounds the blast radius of a bad revision. No
  screen reads either yet.
- [ ] **Semantic (AI) suggestions are built but OFF.** Classification runs on a
  local BM25 index with fuzzy + phonetic matching (`hsn.retrieval.ts`) —
  deterministic, offline, free, sub-millisecond, and it answers every real
  product name in the test suite. Embeddings only add paraphrase with no shared
  vocabulary ("thing you fry pakoras in" → cooking oil). To enable when
  scaling: set `HSN_SEMANTIC=1` plus `GEMINI_API_KEY`, and the vectors file is
  already generated at `modules/hsn/copy/hsn.vectors.json`. Cost is one API
  request per novel product name (cached 30 days in Redis).
- [x] **Log no-result suggestions.** `hsn_lookup_misses` records every product
  name the classifier can't place, upserted per (shop, term) so a retype counts
  once. `GET /hsn/gaps` (platform-admin) aggregates them across shops,
  most-searched first; `POST /hsn/gaps/resolve` closes one after an alias is
  added, and the logger re-opens it automatically if the term still misses —
  which is the only real proof the alias worked. Curation is now a finite,
  ranked backlog rather than guesswork.
- [ ] **Log *corrected* suggestions.** The other half: when a merchant is shown
  suggestions and picks something else (or types a code by hand), our ranking
  was wrong in a way a miss doesn't capture. Needs the client to report the
  chosen code alongside what was offered — one call on selection, not per
  keystroke. Higher-signal than misses; deferred only because it touches both
  product forms.
- [ ] **No UI for the gaps backlog.** `/hsn/gaps` is API-only. It belongs on the
  platform-admin surface next to Category taxonomy, ideally with the alias edit
  inline so closing a gap and marking it resolved are one action.
- [ ] **Variant-level HSN.** The backend derives a variant's rate from its own
  code, but neither product form exposes the field; variants inherit the
  product.
- [ ] **Hindi copy is machine-drafted.** `hsn.copy.hi.json` needs a native
  review, especially the trade vocabulary — a shopkeeper's word for a thing is
  often not the dictionary word.

## Developer environment switcher (Aug 2026)

Settings → Developer lets the developer account point this browser at a
different backend (production / dev tunnel / local). The choice lives in an
httpOnly `sxm_env` cookie read by `resolveBackendBaseUrl()`, so it is scoped to
one browser and never moves another merchant's requests; the allow-list is
`src/shared/config/environments.ts` and `GET|POST /api/dev/environment` 404s for
everyone but `DEVELOPER_EMAIL`. Mirrors the Flutter merchant app's
`frontend/lib/features/developer/`.

- [x] **`customer-web` has a switcher.** Same three pieces, ported:
  `shared/config/environments.ts` (own `sxc_env` cookie — merchant and
  customer share a host in dev and cookies are not port-scoped, so a shared
  name would have one app's switch redirect the other's proxy),
  `resolveBackendBaseUrl()` in `server/auth/session.ts`, and a gated
  `/api/dev/environment`. Surfaced on `/account`.
- [ ] **Deliberately not localised.** The section label, blurb and picker copy
  are hardcoded English and skipped in `messages/*.json` — the whole surface is
  gated to one hardcoded address. If it ever opens up to more accounts, these
  strings need catalog entries.
- [x] **Uses the app's own modal**, not `window.confirm`.
- [x] **Environment badge.** `features/settings/environment-badge.tsx`, in the
  dashboard layout: a developer-only chip shown ONLY while a non-default
  backend is in force. The Flutter merchant app has the same badge in
  `AppShell` (`features/developer/presentation/widgets/environment_badge.dart`).

## Invoice parity: web caught up with Flutter (Aug 2026)

Ported from the Flutter merchant app so both clients issue documents the same
way: place of supply derived (never asked), the Rule 46(e)/(f) recipient gate,
the pre-issue preview, and the archived-invoices view.

- [x] **Place of supply is derived.** `features/invoices/place-of-supply.ts`
  mirrors the backend's GST-10 fallback: counterparty state code → their GSTIN
  prefix → typed GSTIN prefix → the shop's own state. The walk-in state
  `SelectField` is gone; a read-only row shows the answer and why.
- [x] **Recipient gate.** `recipient-gate.tsx` — fill the address (optionally
  saving it back to the customer) or issue anyway with an explicit
  acknowledgement. Warns in more cases than the server blocks, on purpose:
  the server counts a GSTIN-derived state code as an address, so B2B never
  trips its address branch.
- [x] **Preview before confirm.** `invoice-preview.tsx`, on the confirm path
  only — saving a draft stays one click.
- [x] **Archived invoices** at `/dashboard/invoices/archived`, linked from the
  invoices header. Replaces Delete, which the backend could never honour.

Deferred / simplified:

- [x] **Party address is fetched on select.** `invoice-editor.tsx` pulls the
  full party row when one is attached and keys the result to that party's id,
  so switching customers reads as "not loaded yet" rather than briefly showing
  the previous customer's address. The invoice snapshot remains the fallback.
  The preview had the same gap and got the same fix.
- [x] **Per-line discounts exist on web now.** They always existed in the
  Flutter editor and the backend schema, so editing a Flutter-created invoice
  on web silently zeroed them — a data-loss bug, not just a missing field.
  `InvoiceLineDraft.discount` is loaded, edited, sent, and netted off in both
  `computeInvoiceTotals` and the preview.
- [x] **Challans and quotations archive too.** `archivedAt` on both models,
  `POST /:id/archive|unarchive`, an `archived` list filter, and archived views
  at `/dashboard/challans/archived` and `/dashboard/quotations/archived`.

  Two rules differ from invoices, and are enforced server-side so the message
  can explain itself: a PENDING challan is refused (goods are out against it,
  and it has been neither invoiced nor cancelled), and a REQUESTED/PENDING
  quotation is refused (the customer can still act on it, and an accept
  landing against a document the merchant can't see is nobody's job to chase).

  Quotation archiving is merchant-side ONLY — `listForParty` deliberately has
  no `archivedAt` filter. Archiving is the merchant's filing decision and must
  not erase the counterparty's record of what they were quoted. Invoices
  already worked this way (`meService.listInvoicesForParty` ignores it too).

- [x] **One archived-page implementation per platform.** `shared/ui/
  archived-documents-page.tsx` and the Flutter `ArchivedDocumentsPage` back
  all three document kinds, so the filter tabs, day grouping and restore
  affordance can't drift apart.

Deferred from this pass:

- [ ] **Place-of-supply override is deliberately narrow.** Offered only when
  the derivation fell back to the shop's own state. A GSTIN or a saved address
  IS the answer, and overriding those is precisely how tax lands under the
  wrong head — the thing deriving the field was meant to prevent. The case it
  covers is a walk-in with no GSTIN standing in another state.
- [ ] **`DayDivider` is only used by the archived pages.** The main invoices /
  challans / quotations lists could adopt it (the Flutter side already groups
  every dated list by day).
