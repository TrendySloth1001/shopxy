-- Enable trigram extension and add GIN indexes for ILIKE %term% search on
-- name/sku/barcode in the hottest list endpoints. Without these, search
-- degrades to a seq scan once tables exceed a few thousand rows.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS "products_name_trgm"    ON "products"    USING gin ("name" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "products_sku_trgm"     ON "products"    USING gin ("sku" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "products_barcode_trgm" ON "products"    USING gin ("barcode" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "vendors_name_trgm"     ON "vendors"     USING gin ("name" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "parties_name_trgm"     ON "parties"     USING gin ("name" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "invoices_invoice_no_trgm" ON "invoices" USING gin ("invoice_no" gin_trgm_ops);
