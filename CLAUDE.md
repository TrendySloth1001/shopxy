<!-- Docs / READMEs -->
## Docs & READMEs — write them in `readmes/`

**Do NOT scatter `.md` docs across the repo.** Any README, design note, audit,
plan, or working doc you create goes in the root **`readmes/`** folder, which is
**gitignored** (local-only — never committed). The only tracked markdown that
belongs elsewhere is: the `CLAUDE.md` files, `GEMINI.md`, and durable context
files like `POS_PAYMENTS_CONTEXT.md` / `ACCOUNTING_AUDIT.md`. Before adding a new
top-level or per-module `.md`, put it under `readmes/` instead.

<!-- Project layout -->
## Project layout

```
shopxy/
  backend/        Express + Prisma + Postgres. Same backend serves both apps.
  frontend/       Merchant app (Flutter). Manages inventory, invoices, parties, vendors.
  customer/       Customer-side companion app (Flutter). Shows invitations and per-shop
                  invoice ledgers. Same JWT shape as the merchant app — one user can
                  log into either app with the same credentials.
```

Both Flutter apps point at `AppConfig.apiBaseUrl` (in `lib/core/config/app_config.dart`).
The Postgres schema is shared; the two apps differ only in which subset of endpoints they call.

### Key cross-app concepts

- **Linking**: `Party.linked_user_id` / `Vendor.linked_user_id` (nullable FK → users).
  Set when a customer accepts an invitation. The customer app's `/me/links` endpoint
  filters off these columns to show "your shops."
- **Invitations**: see `backend/src/modules/invitations/`. Owners send via the merchant
  app's `SendInvitePage`; recipients accept via the customer app's `NotificationsPage`.
  Pending invites are claimed at signup time via `claimPendingForNewUser` so a
  brand-new user sees them on first login.
- **Notifications** are per-user; same module powers the bell in both apps.

### Running things

| Task | Working dir | Command |
|------|-------------|---------|
| Backend dev server | `backend/` | `npm run dev` |
| Backend type-check | `backend/` | `npx tsc --noEmit` |
| Backend migration | `backend/` | `npx prisma migrate dev` |
| Merchant app | `frontend/` | `flutter run` |
| Merchant analyze | `frontend/` | `flutter analyze` |
| Customer app | `customer/` | `flutter run` |
| Customer analyze | `customer/` | `flutter analyze` |
| Customer tests | `customer/` | `flutter test` |

The customer app was scaffolded as a separate Flutter project (not a monorepo package);
common Dart code is duplicated rather than extracted. Keep that in mind when editing
shared bits (theme tokens, `ApiClient`, notifications feature) — touch both.

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
|------|----------|
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.

### Graph coverage caveat

The graph was initially built against `frontend/` + `backend/` only. The `customer/`
app was scaffolded later and may not yet be indexed. If a query about a customer-app
symbol comes back empty, fall back to Grep/Read in `customer/` and ask the user
whether to rebuild the graph against the new layout.
