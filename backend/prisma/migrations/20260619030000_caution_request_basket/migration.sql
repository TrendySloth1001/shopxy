-- Caution requests: optional shopping basket the customer browsed when sizing
-- the deposit. Read-only context/justification (not earmarked to the goods).
-- Additive only — two nullable columns.

ALTER TABLE "caution_requests" ADD COLUMN "basket" JSONB;
ALTER TABLE "caution_requests" ADD COLUMN "basket_value" DECIMAL(14,2);
