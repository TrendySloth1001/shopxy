-- Link a CREDIT_NOTE (POS sales return) back to the original SALE invoice it
-- reverses, so return quantities can be tracked and capped.
ALTER TABLE "invoices" ADD COLUMN "original_invoice_id" INTEGER;
CREATE INDEX "invoices_original_invoice_id_idx" ON "invoices"("original_invoice_id");
