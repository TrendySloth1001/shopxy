# CLAUDE.md — merchant-web

Next.js 16 (App Router) · TypeScript · Tailwind v4 · merchant-facing web app.
Runs on **port 3010**. Companion to `customer-web` (port 3009); keep shared
conventions (tokens, auth, these rules) in sync across both.

## Before implementing a new feature — read PENDING.md

**MUST** read `PENDING.md` before building any new feature or screen. It tracks
stubbed/deferred wiring (e.g. dashboard rows that should link out, the pending-
invite callout, the notification bell) that may need to be connected once the
feature you're building lands. When you finish an item, tick it off; when you
stub, defer, or simplify something, **add a row to `PENDING.md`** so it isn't
forgotten.

## Layout & responsiveness — read before building any screen

- **MUST use the full width of the page.** App screens (dashboard, lists,
  detail, settings) span the available width with padding — do **not** wrap
  content in a narrow centered rail (`mx-auto max-w-*`). The only exception is
  focused single-column **forms** (sign in / register / accept-invite), which
  stay centered in `max-w-form`.
- **MUST be responsive.** Every component and screen has to work from a phone
  width up to a wide desktop. Use fluid layouts (`flex`, `grid`) with the
  responsive prefixes (`sm: md: lg: xl:`); never hardcode a fixed page width or
  assume desktop. Stack on small screens, spread into columns on large ones.
  Test mentally at ~360px, ~768px, and ~1440px.
- Content padding comes from spacing tokens (`px-lg`, `py-xxxl`); section
  rhythm uses `xxl`/`xxxl`.
- **Buttons size to content — never inflate.** A button's width is its label +
  horizontal padding at a fixed token height (`h-9` compact, `h-10` default,
  `h-11` primary). **MUST NOT** put `w-full` on a button, and **MUST NOT** let a
  button be the lone stretched child of a grid cell / `flex-1` slot (that's what
  blows them up into giant bars). Group related actions in a left-aligned
  `flex flex-wrap items-center gap-sm` row so each keeps its natural width and
  wraps to the next line on narrow screens. Full-width is allowed ONLY for a
  single primary submit inside a focused `max-w-form` form (sign in / register).
  Toolbar/section actions are icon+label chips, not full-width blocks.

## Design system — tokens only

- Tokens are the source of truth: `src/shared/ui/tokens.ts` + the Tailwind
  `@theme` in `src/app/globals.css`. The default colour/radius/shadow scales
  are reset, so only house tokens compile.
- **MUST NOT** write raw colours, hex, or arbitrary pixel values. Use token
  utilities (`bg-canvas`, `text-muted`, `border-hairline`, `rounded-button`,
  `gap-lg`, `text-headline-md`). Add a token before using a new value.
- **Prefer dividers and whitespace over boxes.** Group with hairline dividers
  (`<Divider />`, `border-hairline`), not bordered/elevated cards. Nothing
  chunky: thin borders, restrained radii, one subtle shadow scale.
- Every interactive element defines hover / focus-visible / disabled states
  from tokens. Icons via `lucide-react`.

## Auth & data

- Auth is a BFF: `src/app/api/auth/*` route handlers proxy the backend and
  store JWTs in httpOnly cookies. `API_BASE_URL` is **server-only** (validated
  in `src/shared/config/env.ts`) — never expose the backend URL or a token to
  the client; proxy backend data and images through `/api/*` routes.
- **MUST** validate every external input at the boundary with zod (route
  handlers and forms), mirroring the backend rules. No `any`.
- Protected pages live behind `middleware.ts` (cookie gate) + `RequireAuth`.

## Definition of done

- `npx eslint src` and `npm run build` both pass clean (no `any`, no disables).
- New screens are full-width and responsive; UI uses tokens only.
- Inputs validated; nothing secret reaches the client.
