-- ────────────────────────────────────────────────────────────────────
-- Carousels Phase 1
--
-- Adds the Carousel parent entity + slide-mode discriminator + freeform
-- payload columns on banners. Every step is idempotent (DO blocks guard
-- on existence) so partial reruns on the dev shadow DB are safe.
--
-- Backfill semantics: every existing `banners` row is grouped by
-- (sponsor_shop_id, placement) into a single carousel per group. Rows
-- with sponsor_shop_id IS NULL collapse to a single platform-curated
-- carousel per placement. After this migration no `banners` row should
-- have carousel_id IS NULL; a follow-up migration in Phase 7 will
-- enforce NOT NULL once the new editor has been live for a release.
-- ────────────────────────────────────────────────────────────────────

-- 1. Slide-mode discriminator enum.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'BannerSlideMode'
  ) THEN
    CREATE TYPE "BannerSlideMode" AS ENUM ('TEMPLATED', 'FREEFORM');
  END IF;
END$$;

-- 2. Carousel parent table.
CREATE TABLE IF NOT EXISTS "carousels" (
  "id"         SERIAL PRIMARY KEY,
  "shop_id"    INTEGER,
  "name"       VARCHAR(80) NOT NULL,
  "placement"  "BannerPlacement" NOT NULL,
  "is_active"  BOOLEAN NOT NULL DEFAULT TRUE,
  "start_at"   TIMESTAMP(3),
  "end_at"     TIMESTAMP(3),
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- No DEFAULT on updated_at: Prisma's @updatedAt directive manages
  -- this field in app code; a SQL-level DEFAULT trips `migrate dev`
  -- into auto-generating a follow-up ALTER on every regen.
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "carousels_shop_id_fkey"
    FOREIGN KEY ("shop_id") REFERENCES "shops"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "carousels_shop_id_placement_is_active_idx"
  ON "carousels"("shop_id", "placement", "is_active");
CREATE INDEX IF NOT EXISTS "carousels_placement_is_active_idx"
  ON "carousels"("placement", "is_active");

-- 3. Add discriminator + freeform payload + carousel FK columns to banners.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'banners' AND column_name = 'mode'
  ) THEN
    ALTER TABLE "banners"
      ADD COLUMN "mode" "BannerSlideMode" NOT NULL DEFAULT 'TEMPLATED';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'banners' AND column_name = 'carousel_id'
  ) THEN
    ALTER TABLE "banners" ADD COLUMN "carousel_id" INTEGER;
    ALTER TABLE "banners"
      ADD CONSTRAINT "banners_carousel_id_fkey"
      FOREIGN KEY ("carousel_id") REFERENCES "carousels"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'banners' AND column_name = 'text_blocks'
  ) THEN
    ALTER TABLE "banners" ADD COLUMN "text_blocks" JSONB;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'banners' AND column_name = 'image_transform'
  ) THEN
    ALTER TABLE "banners" ADD COLUMN "image_transform" JSONB;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS "banners_carousel_id_sort_order_idx"
  ON "banners"("carousel_id", "sort_order");

-- 4. Backfill carousels from existing banners.
--    One carousel per (sponsor_shop_id, placement) pair for merchant
--    banners; one per placement for platform-admin banners (NULL
--    sponsor_shop_id collapses into a single shared bucket).
--
--    The carousel name is derived from the placement so existing
--    surfaces stay recognizable to merchants in the new manager UI;
--    the merchant can rename whenever they like.
DO $$
DECLARE
  rec RECORD;
  cid INTEGER;
BEGIN
  FOR rec IN
    SELECT
      sponsor_shop_id,
      placement,
      CASE placement
        WHEN 'HERO'         THEN 'Hero carousel'
        WHEN 'AD_STRIP'     THEN 'Ad strip'
        WHEN 'PROMO'        THEN 'Promo banner'
        WHEN 'CURATED_RAIL' THEN 'Curated rail'
      END AS bucket_name
    FROM "banners"
    WHERE carousel_id IS NULL
    GROUP BY sponsor_shop_id, placement
  LOOP
    INSERT INTO "carousels" (shop_id, name, placement, is_active, sort_order)
    VALUES (rec.sponsor_shop_id, rec.bucket_name, rec.placement, TRUE, 0)
    RETURNING id INTO cid;

    UPDATE "banners"
       SET carousel_id = cid
     WHERE carousel_id IS NULL
       AND placement = rec.placement
       AND sponsor_shop_id IS NOT DISTINCT FROM rec.sponsor_shop_id;
  END LOOP;
END$$;
