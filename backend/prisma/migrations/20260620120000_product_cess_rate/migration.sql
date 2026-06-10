-- Compensation cess rate on the product master. Invoice/quotation engines
-- fall back to this when a line omits cessRate (mirrors taxPercent), so
-- cess-bearing goods (tobacco, aerated drinks, luxury) stop defaulting to 0.
ALTER TABLE "products" ADD COLUMN "cess_rate" DECIMAL(5,2) NOT NULL DEFAULT 0;
