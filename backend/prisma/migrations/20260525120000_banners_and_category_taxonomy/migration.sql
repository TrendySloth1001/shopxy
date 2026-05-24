-- ────────────────────────────────────────────────────────────────────
-- Category taxonomy: parent_id (self-FK, root = NULL) and slug (unique,
-- URL-safe identifier). Existing rows need a backfilled slug derived
-- from name before the unique constraint is added.
-- ────────────────────────────────────────────────────────────────────

ALTER TABLE "categories"
  ADD COLUMN "parent_id" INTEGER,
  ADD COLUMN "slug"      TEXT;

-- Backfill slug: lower-case + non-alnum → '-' + collapse + trim. Disambiguate
-- with `-<id>` suffix to guarantee uniqueness (avoids handling collisions
-- here at DDL time when two categories share the same name pattern).
UPDATE "categories"
   SET "slug" = lower(
         regexp_replace(
           regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'),
           '(^-+|-+$)', '', 'g'
         )
       ) || '-' || id;

ALTER TABLE "categories"
  ALTER COLUMN "slug" SET NOT NULL;

CREATE UNIQUE INDEX "categories_slug_key" ON "categories"("slug");
CREATE INDEX "categories_parent_id_idx" ON "categories"("parent_id");

-- Self-referential parent FK. SetNull rather than Cascade so re-parenting
-- a top-level taxonomy node doesn't accidentally orphan unrelated trees.
ALTER TABLE "categories"
  ADD CONSTRAINT "categories_parent_id_fkey"
  FOREIGN KEY ("parent_id") REFERENCES "categories"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- ────────────────────────────────────────────────────────────────────
-- Banner: home-page placement records. Indexed by (placement, active,
-- window) since the public read filters on all four together.
-- ────────────────────────────────────────────────────────────────────

CREATE TYPE "BannerPlacement" AS ENUM ('HERO', 'AD_STRIP', 'PROMO', 'CURATED_RAIL');

CREATE TABLE "banners" (
    "id"              SERIAL NOT NULL,
    "placement"       "BannerPlacement" NOT NULL,
    "title"           TEXT NOT NULL,
    "subtitle"        TEXT,
    "eyebrow"         TEXT,
    "cta_text"        TEXT,
    "cta_target"      TEXT,
    "brand_label"     TEXT,
    "image_url"       TEXT NOT NULL,
    "bg_color"        TEXT NOT NULL,
    "accent_color"    TEXT,
    "sort_order"      INTEGER NOT NULL DEFAULT 0,
    "start_at"        TIMESTAMP(3),
    "end_at"          TIMESTAMP(3),
    "is_active"       BOOLEAN NOT NULL DEFAULT true,
    "sponsor_shop_id" INTEGER,
    "created_at"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"      TIMESTAMP(3) NOT NULL,

    CONSTRAINT "banners_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "banners_placement_is_active_start_at_end_at_idx"
  ON "banners"("placement", "is_active", "start_at", "end_at");

CREATE INDEX "banners_sponsor_shop_id_idx"
  ON "banners"("sponsor_shop_id");

ALTER TABLE "banners"
  ADD CONSTRAINT "banners_sponsor_shop_id_fkey"
  FOREIGN KEY ("sponsor_shop_id") REFERENCES "shops"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
