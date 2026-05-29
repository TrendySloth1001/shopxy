-- Customer-initiated quote requests: a linked customer builds a basket and
-- sends it; the merchant prices it and turns it into a PENDING quotation.
-- `requested_by_id` marks the initiating customer. Additive only.

ALTER TABLE "quotations" ADD COLUMN "requested_by_id" INTEGER;

ALTER TABLE "quotations" ADD CONSTRAINT "quotations_requested_by_id_fkey" FOREIGN KEY ("requested_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
