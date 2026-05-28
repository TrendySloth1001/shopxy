-- Banner-product discount becomes typed (percent OR rupee amount) and
-- stops being display-only — it now feeds invoice line discounts.

CREATE TYPE "BannerProductDiscountType" AS ENUM ('PERCENT', 'AMOUNT');

ALTER TABLE "banner_products"
  ADD COLUMN "discount_type"  "BannerProductDiscountType" NOT NULL DEFAULT 'PERCENT',
  ADD COLUMN "discount_value" DECIMAL(12, 2)              NOT NULL DEFAULT 0;

-- Backfill: existing int percent rows become PERCENT/value=<old int>.
UPDATE "banner_products"
SET    "discount_value" = "discount_pct"
WHERE  "discount_pct" > 0;

ALTER TABLE "banner_products" DROP COLUMN "discount_pct";
