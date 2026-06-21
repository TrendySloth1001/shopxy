-- CAT-H1: a ProductVariant can legitimately differ in HSN / GST slab from its
-- parent product (combo vs single, different material). Mirror the parent's
-- hsn_code (TEXT NULL) and tax_percent (DECIMAL(5,2) NOT NULL DEFAULT 0) onto
-- the variant so the invoice engine can source the rate from the chosen variant.
-- Applied additively (IF NOT EXISTS) because the products.search_vector generated
-- column blocks `prisma migrate dev`; resolved with `migrate resolve --applied`.
ALTER TABLE "product_variants" ADD COLUMN IF NOT EXISTS "hsn_code" TEXT;
ALTER TABLE "product_variants" ADD COLUMN IF NOT EXISTS "tax_percent" DECIMAL(5,2) NOT NULL DEFAULT 0;
