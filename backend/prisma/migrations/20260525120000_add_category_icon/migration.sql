-- Adds an optional kebab-case icon name to categories so the merchant
-- app can render a recognisable glyph (grocery, electronics, fashion, ...)
-- per category. Storing the name (not the icon bytes) keeps the column
-- tiny and lets us swap icon packs later without a backfill.
ALTER TABLE "categories" ADD COLUMN "icon_name" TEXT;
