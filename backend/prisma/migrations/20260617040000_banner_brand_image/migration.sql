-- Brand logo / mark for the slide-card brand chip. Optional URL +
-- fit-mode (reuses the existing BannerImageFit enum so the merchant
-- editor can present the same Cover/Contain toggle as the main image).
ALTER TABLE "banners"
  ADD COLUMN IF NOT EXISTS "brand_image_url" TEXT;

ALTER TABLE "banners"
  ADD COLUMN IF NOT EXISTS "brand_image_fit" "BannerImageFit" NOT NULL DEFAULT 'COVER';
