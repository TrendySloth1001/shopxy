-- Audit remediation: CAT-C2, CAT-C4, AUTH-TR-C1, CASH-1, GST-5/PR-C1.
-- Additive + index reshaping only. Applied to the dev DB out-of-band via
-- `prisma db execute` (the products.search_vector generated column blocks
-- `prisma migrate dev`); this file mirrors that DDL so other environments
-- stay reproducible. Idempotent guards let it re-run safely.

-- CAT-C2: country of origin on products.
ALTER TABLE "products" ADD COLUMN IF NOT EXISTS "country_of_origin" text;

-- CAT-C4: per-shop unique SKU/barcode instead of global.
-- Drop the global uniques (constraint and/or bare-index representations).
ALTER TABLE "products" DROP CONSTRAINT IF EXISTS "products_sku_key";
ALTER TABLE "products" DROP CONSTRAINT IF EXISTS "products_barcode_key";
DROP INDEX IF EXISTS "products_sku_key";
DROP INDEX IF EXISTS "products_barcode_key";
ALTER TABLE "product_variants" DROP CONSTRAINT IF EXISTS "product_variants_sku_key";
ALTER TABLE "product_variants" DROP CONSTRAINT IF EXISTS "product_variants_barcode_key";
DROP INDEX IF EXISTS "product_variants_sku_key";
DROP INDEX IF EXISTS "product_variants_barcode_key";

-- Products: per-shop unique sku; partial unique barcode (NULLs allowed).
CREATE UNIQUE INDEX IF NOT EXISTS "products_shop_id_sku_key" ON "products" ("shop_id", "sku");
CREATE UNIQUE INDEX IF NOT EXISTS "products_shop_id_barcode_key" ON "products" ("shop_id", "barcode") WHERE "barcode" IS NOT NULL;

-- Variants have no shop_id; scope uniqueness by product_id.
CREATE UNIQUE INDEX IF NOT EXISTS "product_variants_product_id_sku_key" ON "product_variants" ("product_id", "sku");
CREATE UNIQUE INDEX IF NOT EXISTS "product_variants_product_id_barcode_key" ON "product_variants" ("product_id", "barcode") WHERE "barcode" IS NOT NULL;

-- AUTH-TR-C1: tie a return line to the exact invoice line it reverses.
ALTER TABLE "return_request_items" ADD COLUMN IF NOT EXISTS "invoice_item_id" integer;
CREATE INDEX IF NOT EXISTS "return_request_items_invoice_item_id_idx" ON "return_request_items" ("invoice_item_id");

-- CASH-1: tie credit notes to the issuing till/cashier.
ALTER TABLE "invoices" ADD COLUMN IF NOT EXISTS "shift_id" integer;
ALTER TABLE "invoices" ADD COLUMN IF NOT EXISTS "created_by_id" integer;
CREATE INDEX IF NOT EXISTS "invoices_shift_id_idx" ON "invoices" ("shift_id");
CREATE INDEX IF NOT EXISTS "invoices_created_by_id_idx" ON "invoices" ("created_by_id");

-- GST-5/PR-C1: record whether a line's unitPrice was tax-inclusive.
ALTER TABLE "invoice_items" ADD COLUMN IF NOT EXISTS "is_price_inclusive" boolean NOT NULL DEFAULT false;
