-- ────────────────────────────────────────────────────────────────────
-- Flash sales: time-bound discount with a hard stock cap. Indexed for
-- the two hot reads:
--   (product_id, is_active)        — "is there an active sale for this product?"
--   (is_active, start_at, end_at)  — public listing of currently-running sales
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE "flash_sales" (
    "id"          SERIAL NOT NULL,
    "product_id"  INTEGER NOT NULL,
    "flash_price" DECIMAL(12,2) NOT NULL,
    "stock_limit" INTEGER NOT NULL,
    "sold_count"  INTEGER NOT NULL DEFAULT 0,
    "start_at"    TIMESTAMP(3) NOT NULL,
    "end_at"      TIMESTAMP(3) NOT NULL,
    "is_active"   BOOLEAN NOT NULL DEFAULT true,
    "created_at"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"  TIMESTAMP(3) NOT NULL,

    CONSTRAINT "flash_sales_pkey" PRIMARY KEY ("id"),

    -- Defence in depth: forbids stock_limit ≤ 0 (no infinite-cap sales)
    -- and flash_price ≥ 0 (free flash items would crater margins
    -- without being deliberate — a merchant typing 0 by accident is the
    -- most likely cause).
    CONSTRAINT "flash_sales_stock_limit_positive" CHECK ("stock_limit" > 0),
    CONSTRAINT "flash_sales_flash_price_nonneg"   CHECK ("flash_price" >= 0),
    CONSTRAINT "flash_sales_window_ordered"       CHECK ("end_at" > "start_at")
);

CREATE INDEX "flash_sales_product_id_is_active_idx"
  ON "flash_sales"("product_id", "is_active");

CREATE INDEX "flash_sales_is_active_start_at_end_at_idx"
  ON "flash_sales"("is_active", "start_at", "end_at");

-- Partial unique index: at most one ACTIVE flash sale per product at
-- any time. Inactive (cancelled / expired) historical rows are
-- excluded so a product can run many sales over its lifetime, just
-- never two concurrently. Prisma 7 can't model partial indexes
-- declaratively yet — hence the raw DDL here.
CREATE UNIQUE INDEX "flash_sales_one_active_per_product"
  ON "flash_sales"("product_id")
  WHERE "is_active" = true;

ALTER TABLE "flash_sales"
  ADD CONSTRAINT "flash_sales_product_id_fkey"
  FOREIGN KEY ("product_id") REFERENCES "products"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
