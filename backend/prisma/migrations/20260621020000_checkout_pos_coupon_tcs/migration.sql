-- PR-C2: structured place-of-supply (shipping address) snapshot on the order + child.
ALTER TABLE "customer_orders"
  ADD COLUMN "ship_city" TEXT,
  ADD COLUMN "ship_state" TEXT,
  ADD COLUMN "ship_state_code" TEXT,
  ADD COLUMN "ship_pincode" TEXT;

-- CWQ-1: the shop a seller-funded coupon is bound to (NULL = platform-funded).
ALTER TABLE "customer_orders"
  ADD COLUMN "coupon_shop_id" INTEGER;

ALTER TABLE "purchase_requests"
  ADD COLUMN "ship_city" TEXT,
  ADD COLUMN "ship_state" TEXT,
  ADD COLUMN "ship_state_code" TEXT,
  ADD COLUMN "ship_pincode" TEXT;

-- PR-C3: e-commerce-operator GST TCS (Sec 52) + income-tax TDS (Sec 194-O)
-- withheld per seller slice of a captured order, for GSTR-8 / 26Q reporting.
CREATE TABLE "operator_withholdings" (
  "id" SERIAL NOT NULL,
  "gateway_payment_id" INTEGER NOT NULL,
  "purchase_request_id" INTEGER NOT NULL,
  "shop_id" INTEGER NOT NULL,
  "net_taxable" DECIMAL(12,2) NOT NULL,
  "gross_amount" DECIMAL(12,2) NOT NULL,
  "is_interstate" BOOLEAN NOT NULL,
  "cgst_tcs" DECIMAL(12,2) NOT NULL DEFAULT 0,
  "sgst_tcs" DECIMAL(12,2) NOT NULL DEFAULT 0,
  "igst_tcs" DECIMAL(12,2) NOT NULL DEFAULT 0,
  "gst_tcs_total" DECIMAL(12,2) NOT NULL DEFAULT 0,
  "income_tax_tds" DECIMAL(12,2) NOT NULL DEFAULT 0,
  "total_withheld" DECIMAL(12,2) NOT NULL DEFAULT 0,
  "applied" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "operator_withholdings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "operator_withholding_payment_request"
  ON "operator_withholdings" ("gateway_payment_id", "purchase_request_id");

CREATE INDEX "operator_withholdings_shop_id_created_at_idx"
  ON "operator_withholdings" ("shop_id", "created_at");

ALTER TABLE "operator_withholdings"
  ADD CONSTRAINT "operator_withholdings_purchase_request_id_fkey"
  FOREIGN KEY ("purchase_request_id") REFERENCES "purchase_requests" ("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
