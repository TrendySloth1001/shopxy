-- Remove the freeform slide system entirely. Drop the discriminator
-- column + every JSON payload column the freeform editor wrote into,
-- then drop the now-unused enum type. Templated slides keep working
-- unchanged — every other column on `banners` is preserved.

ALTER TABLE "banners" DROP COLUMN IF EXISTS "mode";
ALTER TABLE "banners" DROP COLUMN IF EXISTS "text_blocks";
ALTER TABLE "banners" DROP COLUMN IF EXISTS "image_transform";
ALTER TABLE "banners" DROP COLUMN IF EXISTS "image_blocks";

DROP TYPE IF EXISTS "BannerSlideMode";
