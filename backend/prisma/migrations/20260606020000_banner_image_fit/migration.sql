-- Per-slide image-fit choice. COVER (default) crops to fill the slot
-- the way every existing banner did before this field; CONTAIN
-- letterboxes so merchants can ship ready-made artwork without clip.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'BannerImageFit'
  ) THEN
    CREATE TYPE "BannerImageFit" AS ENUM ('COVER', 'CONTAIN');
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM information_schema.columns
     WHERE table_name = 'banners' AND column_name = 'image_fit'
  ) THEN
    ALTER TABLE "banners"
      ADD COLUMN "image_fit" "BannerImageFit" NOT NULL DEFAULT 'COVER';
  END IF;
END$$;
