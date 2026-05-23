-- GST-compliant invoice schema (P7a).
--   * Splits Invoice.tax_amount into igst/cgst/sgst/cess explicitly.
--   * Adds place-of-supply, FY, document_type, round-off, amount-in-words.
--   * Adds full address (state + state_code + pin) to Party, Vendor, Invoice snapshots.
--   * Adds shop profile + UPI VPA to User.
-- Backfill assumes existing rows are intrastate (cgst = sgst = tax_amount/2).

-- ── Invoice header ──────────────────────────────────────────────────────────
ALTER TABLE "invoices" ADD COLUMN "document_type"            TEXT NOT NULL DEFAULT 'TAX_INVOICE';
ALTER TABLE "invoices" ADD COLUMN "financial_year"           TEXT;
ALTER TABLE "invoices" ADD COLUMN "place_of_supply_state_code" TEXT;
ALTER TABLE "invoices" ADD COLUMN "is_interstate"            BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE "invoices" ADD COLUMN "taxable_value"            NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoices" ADD COLUMN "igst_amount"              NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoices" ADD COLUMN "cgst_amount"              NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoices" ADD COLUMN "sgst_amount"              NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoices" ADD COLUMN "cess_amount"              NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoices" ADD COLUMN "round_off"                NUMERIC(6,2)  NOT NULL DEFAULT 0;
ALTER TABLE "invoices" ADD COLUMN "amount_in_words"          TEXT;

-- Customer + vendor address snapshots (denormalised so historical invoices stay correct
-- even if the party row is later edited).
ALTER TABLE "invoices" ADD COLUMN "customer_address"     TEXT;
ALTER TABLE "invoices" ADD COLUMN "customer_city"        TEXT;
ALTER TABLE "invoices" ADD COLUMN "customer_state"       TEXT;
ALTER TABLE "invoices" ADD COLUMN "customer_state_code"  TEXT;
ALTER TABLE "invoices" ADD COLUMN "customer_pin_code"    TEXT;
ALTER TABLE "invoices" ADD COLUMN "customer_pan_number"  TEXT;

ALTER TABLE "invoices" ADD COLUMN "vendor_address"       TEXT;
ALTER TABLE "invoices" ADD COLUMN "vendor_city"          TEXT;
ALTER TABLE "invoices" ADD COLUMN "vendor_state"         TEXT;
ALTER TABLE "invoices" ADD COLUMN "vendor_state_code"    TEXT;
ALTER TABLE "invoices" ADD COLUMN "vendor_pin_code"      TEXT;
ALTER TABLE "invoices" ADD COLUMN "vendor_pan_number"    TEXT;

-- Backfill financial_year from invoice_date. April → next March is one FY ("25-26").
UPDATE "invoices" SET "financial_year" =
  CASE WHEN EXTRACT(MONTH FROM "invoice_date") >= 4
    THEN LPAD((EXTRACT(YEAR FROM "invoice_date")::int % 100)::text, 2, '0') || '-' ||
         LPAD(((EXTRACT(YEAR FROM "invoice_date")::int + 1) % 100)::text, 2, '0')
    ELSE LPAD(((EXTRACT(YEAR FROM "invoice_date")::int - 1) % 100)::text, 2, '0') || '-' ||
         LPAD((EXTRACT(YEAR FROM "invoice_date")::int % 100)::text, 2, '0')
  END
WHERE "financial_year" IS NULL;
ALTER TABLE "invoices" ALTER COLUMN "financial_year" SET NOT NULL;

-- Backfill taxable_value = subtotal - discount.
UPDATE "invoices" SET "taxable_value" = GREATEST("subtotal" - "discount", 0);

-- Backfill split tax — assume intrastate (50/50 CGST+SGST) since legacy rows have no state info.
UPDATE "invoices"
   SET "cgst_amount" = ROUND("tax_amount" / 2, 2),
       "sgst_amount" = "tax_amount" - ROUND("tax_amount" / 2, 2)
 WHERE "tax_amount" > 0;

-- ── Invoice items ───────────────────────────────────────────────────────────
ALTER TABLE "invoice_items" ADD COLUMN "taxable_value" NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoice_items" ADD COLUMN "igst_amount"   NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoice_items" ADD COLUMN "cgst_amount"   NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoice_items" ADD COLUMN "sgst_amount"   NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "invoice_items" ADD COLUMN "cess_rate"     NUMERIC(5,2)  NOT NULL DEFAULT 0;
ALTER TABLE "invoice_items" ADD COLUMN "cess_amount"   NUMERIC(12,2) NOT NULL DEFAULT 0;

-- Backfill per-line taxable + split (intrastate assumption — see above).
UPDATE "invoice_items"
   SET "taxable_value" = GREATEST(("quantity" * "unit_price") - "discount", 0);

UPDATE "invoice_items"
   SET "cgst_amount" = ROUND(("taxable_value" * "tax_percent" / 100) / 2, 2),
       "sgst_amount" = ROUND(("taxable_value" * "tax_percent" / 100) - ROUND(("taxable_value" * "tax_percent" / 100) / 2, 2), 2)
 WHERE "tax_percent" > 0;

-- ── Party + Vendor address detail ───────────────────────────────────────────
ALTER TABLE "parties" ADD COLUMN "city"        TEXT;
ALTER TABLE "parties" ADD COLUMN "state"       TEXT;
ALTER TABLE "parties" ADD COLUMN "state_code"  TEXT;
ALTER TABLE "parties" ADD COLUMN "pin_code"    TEXT;
ALTER TABLE "parties" ADD COLUMN "pan_number"  TEXT;

ALTER TABLE "vendors" ADD COLUMN "city"        TEXT;
ALTER TABLE "vendors" ADD COLUMN "state"       TEXT;
ALTER TABLE "vendors" ADD COLUMN "state_code"  TEXT;
ALTER TABLE "vendors" ADD COLUMN "pin_code"    TEXT;
ALTER TABLE "vendors" ADD COLUMN "pan_number"  TEXT;

-- ── User: shop profile + UPI VPA ────────────────────────────────────────────
ALTER TABLE "users" ADD COLUMN "shop_name"        TEXT;
ALTER TABLE "users" ADD COLUMN "shop_address"     TEXT;
ALTER TABLE "users" ADD COLUMN "shop_city"        TEXT;
ALTER TABLE "users" ADD COLUMN "shop_state"       TEXT;
ALTER TABLE "users" ADD COLUMN "shop_state_code"  TEXT;
ALTER TABLE "users" ADD COLUMN "shop_pin_code"    TEXT;
ALTER TABLE "users" ADD COLUMN "shop_gstin"       TEXT;
ALTER TABLE "users" ADD COLUMN "shop_pan"         TEXT;
ALTER TABLE "users" ADD COLUMN "upi_vpa"          TEXT;

-- Indexes for new query patterns
CREATE INDEX IF NOT EXISTS "invoices_financial_year_idx"           ON "invoices" ("financial_year");
CREATE INDEX IF NOT EXISTS "invoices_financial_year_type_idx"      ON "invoices" ("financial_year", "type");
CREATE INDEX IF NOT EXISTS "invoices_place_of_supply_idx"          ON "invoices" ("place_of_supply_state_code");
