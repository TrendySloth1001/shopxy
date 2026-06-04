# PENDING.md — customer-web

Deferred wiring and known stubs. **Read this before implementing a new feature**
— when you build something here, check whether it unblocks an item below and
wire it up. **When you stub, defer, or simplify something, add a row here** with
where it lives and what triggers finishing it.

Format: `[ ]` open · `[x]` done. "Trigger" = the feature whose arrival means
this should be revisited.

## Deferred wiring (stubbed — connect when the trigger lands)

- [ ] **Home / dashboard not built yet.** Only auth + `/account` exist. The
  customer home (shops, invitations, per-shop invoice ledgers) is unbuilt.
- [ ] **Notifications / invitations.** The customer app surfaces pending
  invitations and a notification bell. Trigger: notifications feature on web →
  add the bell + a pending-invite surface.

## Layout / shell debt

- [ ] **No app shell yet.** `/account` uses the top `AppHeader`. Decide the
  customer navigation shape (top nav vs sidebar) when the home is built; keep it
  full-width and responsive per CLAUDE.md.

## Quality / infra debt (applies to both web apps)

- [ ] **No automated tests yet.** Add a vitest suite: auth schemas, `extractError`,
  and the BFF route handlers.
- [ ] **Enforcement tooling not wired.** Strict `tsconfig` flags, lint rules
  banning raw hex / arbitrary Tailwind values / inline numeric styles, CI,
  commitlint + husky. CLAUDE.md conventions are followed but not gated.

## Cross-app

- [ ] **Keep tokens + auth + CLAUDE.md in sync with `merchant-web`** when changing
  shared bits (they are duplicated, not extracted). Note merchant-only token
  accents (flashDeal/whatsapp) do not belong here.
