-- Rich product detail fields for the V2 PDP. Each is optional; the
-- customer page collapses sections gracefully when empty so this
-- migration is non-breaking for existing rows.
--
--   highlights — short bullet list rendered above the fold ("6.7-inch
--                AMOLED", "7 years of OS updates"). Stored as text[]
--                like the existing tags column so we can keep using
--                Postgres array ops + the simple Prisma `String[]`
--                projection without a join table.
--
--   specs      — long-form, grouped attributes ("Display features →
--                Resolution: 2340x1080"). Stored as JSONB because the
--                shape is open-ended per category — we'd need a wide
--                category-aware schema to model it cleanly relationally,
--                and the storage and querying cost of jsonb is fine for
--                the size we ship (a few KB per product max).
--                Shape: [{ "title": "...", "rows": [{ "label": "...",
--                "value": "..." }] }]
--
--   offers     — bank/coupon offers rendered as cards beneath the price
--                ("HDFC Credit Card · ₹1500 off", "SHOPXY5 → 5% off").
--                Same JSONB rationale — variable shape and few rows.
--                Shape: [{ "kind": "BANK"|"COUPON"|"EMI"|"EXCHANGE",
--                "headline": "...", "detail": "...", "code": "..."? }]

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS highlights TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS specs      JSONB,
  ADD COLUMN IF NOT EXISTS offers     JSONB;

-- Any change to descriptive fields invalidates the semantic embedding.
-- Bump `embedded_at` to NULL on existing rows that have a non-empty
-- highlights/specs so the embed-pending cron re-embeds them with the
-- new content. (Fresh products start NULL anyway.)
UPDATE products SET embedded_at = NULL WHERE embedded_at IS NOT NULL;
