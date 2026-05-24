-- The canonical taxonomy intentionally reuses display names across
-- different parents ("Footwear" under both Men's Fashion and Women's
-- Fashion, "Tools" under both Automotive and Industrial). `slug` is
-- the unique identifier; `name` is a display label. Drop the legacy
-- unique index — it was put in place for merchant-created categories
-- and now blocks the canonical seed.

DROP INDEX IF EXISTS categories_name_key;
