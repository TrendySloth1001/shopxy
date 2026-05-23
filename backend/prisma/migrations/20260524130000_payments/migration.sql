-- P8 — Party / vendor payment ledger.
-- Payments interleave with invoices on the party + vendor detail page
-- to drive a running balance. Optionally allocated to one invoice
-- (otherwise on-account credit).

CREATE TABLE "payments" (
  "id"             SERIAL PRIMARY KEY,
  "type"           TEXT NOT NULL,
  "reference_no"   TEXT NOT NULL,
  "amount"         NUMERIC(12,2) NOT NULL,
  "mode"           TEXT NOT NULL,
  "mode_reference" TEXT,
  "payment_date"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "party_id"       INTEGER,
  "vendor_id"      INTEGER,
  "invoice_id"     INTEGER,
  "note"           TEXT,
  "created_by_id"  INTEGER,
  "created_at"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"     TIMESTAMP(3) NOT NULL,

  CONSTRAINT "payments_party_id_fkey"
    FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "payments_vendor_id_fkey"
    FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "payments_invoice_id_fkey"
    FOREIGN KEY ("invoice_id") REFERENCES "invoices"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "payments_created_by_id_fkey"
    FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "payments_reference_no_key" ON "payments"("reference_no");
CREATE INDEX "payments_party_id_payment_date_idx"  ON "payments"("party_id", "payment_date");
CREATE INDEX "payments_vendor_id_payment_date_idx" ON "payments"("vendor_id", "payment_date");
CREATE INDEX "payments_invoice_id_idx"             ON "payments"("invoice_id");
