-- SUPPLY forfeits (Circular 178/2022 ¶11.3): the retained advance is
-- GST-inclusive consideration for the cancelled supply. Persist the goods'
-- rate and the inclusive split so the output tax is computed at forfeit
-- time and reportable — previously the flag was stored with no split and
-- the GST on every forfeited supply was silently lost.
ALTER TABLE "caution_txns" ADD COLUMN "tax_rate" DECIMAL(5,2);
ALTER TABLE "caution_txns" ADD COLUMN "taxable_value" DECIMAL(12,2);
ALTER TABLE "caution_txns" ADD COLUMN "tax_amount" DECIMAL(12,2);
