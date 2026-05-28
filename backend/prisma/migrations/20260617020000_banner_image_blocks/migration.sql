-- Add image_blocks JSON column for FREEFORM slides. NULL = no overlay
-- images (the common case for pre-migration rows and any TEMPLATED
-- slide, which ignores this column entirely). The column is read /
-- written via the imageBlocksSchema in freeform-payload.ts so the only
-- valid shape is an array of {id, url, xPct, yPct, widthPct,
-- rotateDeg, opacity} objects.
ALTER TABLE "banners"
  ADD COLUMN IF NOT EXISTS "image_blocks" JSONB;
