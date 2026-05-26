-- Add visual template selection to banners. CLASSIC is the original
-- branded card; merchants can now also pick MINIMAL (editorial layout)
-- or IMAGE_ONLY (just their uploaded artwork, no overlays).
--
-- Guarded with DO blocks so re-runs on partially-migrated shadow DBs
-- are a no-op instead of failing on the existing enum / column.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'BannerTemplate'
  ) THEN
    CREATE TYPE "BannerTemplate" AS ENUM ('CLASSIC', 'MINIMAL', 'IMAGE_ONLY');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM information_schema.columns
     WHERE table_name = 'banners' AND column_name = 'template'
  ) THEN
    ALTER TABLE "banners"
      ADD COLUMN "template" "BannerTemplate" NOT NULL DEFAULT 'CLASSIC';
  END IF;
END$$;
