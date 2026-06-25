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
- [ ] **Receivables / payables ageing.** No `dueDate` / payment-terms column on
  `Invoice`, so the KPIs show outstanding + debtor/creditor counts but **no
  overdue ageing** (0–30 / 31–60 / 60+). Add once invoice due-dates exist.
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
