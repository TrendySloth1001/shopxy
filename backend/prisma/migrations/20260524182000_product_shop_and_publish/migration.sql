-- Add shop_id NULLABLE first so the existing rows survive; backfill;
-- then enforce NOT NULL. Direct ADD COLUMN NOT NULL without a default
-- would fail against the existing 10 product rows.
ALTER TABLE "products" ADD COLUMN "shop_id" INTEGER;
ALTER TABLE "products" ADD COLUMN "is_published" BOOLEAN NOT NULL DEFAULT false;

-- Backfill: assign every existing product to the lowest-id shop. This
-- is dev-data convention only — owners can re-assign / re-publish via
-- the new Shop Profile UI. Will error if zero shops exist, which would
-- indicate the Shop migration didn't run.
UPDATE "products"
   SET "shop_id" = (SELECT MIN(id) FROM "shops")
 WHERE "shop_id" IS NULL;

-- Now enforce NOT NULL.
ALTER TABLE "products" ALTER COLUMN "shop_id" SET NOT NULL;

-- Foreign key: RESTRICT delete prevents a shop with live catalog from
-- being silently dropped; product cleanup must be explicit.
ALTER TABLE "products"
  ADD CONSTRAINT "products_shop_id_fkey"
  FOREIGN KEY ("shop_id") REFERENCES "shops"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

-- Hot read path: marketplace listings filter by (shop_id, is_published).
CREATE INDEX "products_shop_id_is_published_idx"
  ON "products"("shop_id", "is_published");
