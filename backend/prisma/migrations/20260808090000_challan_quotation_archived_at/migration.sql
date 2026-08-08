-- Archiving for challans and quotations, matching invoices.
--
-- Both documents own a per-shop serial allocated at create time (Rule 55 wants
-- the challan run serially numbered), so neither can be hard-deleted without
-- leaving a hole. Archiving files the row out of the working list and keeps
-- the number allocated.
--
-- Only a settled document may be archived: a PENDING challan still has goods
-- out against it, and a REQUESTED/PENDING quotation is a decision the customer
-- has not made yet. Enforced in the service, not here, so the message can
-- explain itself.
ALTER TABLE "challans" ADD COLUMN "archived_at" TIMESTAMP(3);
ALTER TABLE "quotations" ADD COLUMN "archived_at" TIMESTAMP(3);

-- Every default list query filters `archived_at IS NULL`.
CREATE INDEX "challans_shop_id_archived_at_idx" ON "challans"("shop_id", "archived_at");
CREATE INDEX "quotations_shop_id_archived_at_idx" ON "quotations"("shop_id", "archived_at");
