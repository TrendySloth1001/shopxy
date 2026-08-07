-- Archiving replaces deletion for invoices.
--
-- A DRAFT already owns a legal serial (the per-shop FY counter is bumped at
-- create time), so hard-deleting one leaves a permanent hole in a sequence
-- Rule 46(b) requires to be consecutive. `deleteInvoice` therefore never had a
-- success path -- every branch returned an error -- while both clients still
-- offered a Delete button that could only ever fail.
--
-- Archiving files the document out of the working list and KEEPS its number
-- allocated, so the run still reads consecutively to an auditor.
ALTER TABLE "invoices" ADD COLUMN "archived_at" TIMESTAMP(3);

-- Every default list query filters `archived_at IS NULL`.
CREATE INDEX "invoices_shop_id_archived_at_idx" ON "invoices"("shop_id", "archived_at");
