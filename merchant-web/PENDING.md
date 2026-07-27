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

- [ ] **Google SSO ("Continue with Google").** The button is live on the sign-in
  form (`features/auth/components/google-button.tsx`) and points at the BFF route
  `app/api/auth/google/route.ts`, which currently redirects back to
  `/login?reason=google-soon` with a "coming soon" notice. To make it real:
  add backend Google OAuth (authorise + callback, user provisioning for
  password-less accounts, JWT issuance), set `GOOGLE_CLIENT_ID`/`SECRET`, then
  replace the BFF stub with a 302 to the backend authorise URL. Also consider
  adding the button to the register form.

## HSN/SAC rate master (Jul 2026)

The GST rate is no longer typed. The merchant classifies the product — one
input — and the rate is derived: `hsn_codes` holds codes and rates, the
translatable copy catalogues hold the words merchants search by, and the tax
field on the product form is a **readout** with an explicit manual escape
hatch. Backend: `backend/src/modules/hsn/`. Web:
`features/products/components/hsn-field.tsx` + `gst-rate-field.tsx`.

Deferred / open:

- [ ] **Import the real tariff.** `npm run hsn:import -- --directory <codes>
  --rates <rates>` ingests official CBIC data into
  `backend/src/modules/hsn/data/hsn.master.json`, which the seed prefers. Until
  that file is committed, the boot log warns and a ~300-entry hand-written
  **provisional** manifest is used. Nothing should rely on those rates
  commercially — get the download, run the import, commit the diff.
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
