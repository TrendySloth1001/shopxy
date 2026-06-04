-- INV-2: one-shot conversion guard on the source estimate/proforma.
ALTER TABLE "invoices" ADD COLUMN "converted_to_invoice_id" INTEGER;
