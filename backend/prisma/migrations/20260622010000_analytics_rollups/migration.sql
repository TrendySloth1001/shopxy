-- Analytics roll-up tables (Phase 2). Additive only — no changes to existing
-- tables' data. Idempotent (IF NOT EXISTS) so it is safe to (re)apply.

CREATE TABLE IF NOT EXISTS "agg_daily_sales" (
  "shop_id" INTEGER NOT NULL,
  "day" DATE NOT NULL,
  "doc_count" INTEGER NOT NULL DEFAULT 0,
  "taxable" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "tax" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "total" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "refunds" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "cogs" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "returned_cogs" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "writeoffs" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "agg_daily_sales_pkey" PRIMARY KEY ("shop_id","day")
);

CREATE TABLE IF NOT EXISTS "agg_daily_purchases" (
  "shop_id" INTEGER NOT NULL,
  "day" DATE NOT NULL,
  "doc_count" INTEGER NOT NULL DEFAULT 0,
  "taxable" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "tax" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "total" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "agg_daily_purchases_pkey" PRIMARY KEY ("shop_id","day")
);

CREATE TABLE IF NOT EXISTS "agg_daily_payments" (
  "shop_id" INTEGER NOT NULL,
  "day" DATE NOT NULL,
  "type" TEXT NOT NULL,
  "mode" TEXT NOT NULL,
  "amount" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "cnt" INTEGER NOT NULL DEFAULT 0,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "agg_daily_payments_pkey" PRIMARY KEY ("shop_id","day","type","mode")
);
CREATE INDEX IF NOT EXISTS "agg_daily_payments_shop_id_day_idx" ON "agg_daily_payments"("shop_id","day");

CREATE TABLE IF NOT EXISTS "agg_daily_gst" (
  "shop_id" INTEGER NOT NULL,
  "day" DATE NOT NULL,
  "tax_rate" DECIMAL(5,2) NOT NULL,
  "output_tax" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "input_tax" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "output_cess" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "input_cess" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "taxable" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "agg_daily_gst_pkey" PRIMARY KEY ("shop_id","day","tax_rate")
);
CREATE INDEX IF NOT EXISTS "agg_daily_gst_shop_id_day_idx" ON "agg_daily_gst"("shop_id","day");

CREATE TABLE IF NOT EXISTS "agg_daily_product" (
  "shop_id" INTEGER NOT NULL,
  "day" DATE NOT NULL,
  "product_id" INTEGER NOT NULL,
  "category_id" INTEGER,
  "qty" DECIMAL(14,3) NOT NULL DEFAULT 0,
  "revenue" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "agg_daily_product_pkey" PRIMARY KEY ("shop_id","day","product_id")
);
CREATE INDEX IF NOT EXISTS "agg_daily_product_shop_id_day_idx" ON "agg_daily_product"("shop_id","day");

CREATE TABLE IF NOT EXISTS "agg_changefeed_cursor" (
  "name" TEXT NOT NULL,
  "cursor_at" TIMESTAMP(3) NOT NULL,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "agg_changefeed_cursor_pkey" PRIMARY KEY ("name")
);

-- Changefeed scan indexes on the source tables (rows changed since the cursor).
CREATE INDEX IF NOT EXISTS "invoices_updated_at_idx" ON "invoices"("updated_at");
CREATE INDEX IF NOT EXISTS "payments_updated_at_idx" ON "payments"("updated_at");
CREATE INDEX IF NOT EXISTS "return_requests_updated_at_idx" ON "return_requests"("updated_at");
CREATE INDEX IF NOT EXISTS "stock_adjustments_created_at_idx" ON "stock_adjustments"("created_at");
