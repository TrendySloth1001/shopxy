-- GST registration status + payment soft-void audit trail.

-- 1. Registration type enum + column on users.
CREATE TYPE "RegistrationType" AS ENUM ('REGULAR', 'COMPOSITION', 'UNREGISTERED');

ALTER TABLE "users"
  ADD COLUMN "registration_type" "RegistrationType" NOT NULL DEFAULT 'UNREGISTERED';

-- Backfill: any shop that already holds a GSTIN was operating as a regular
-- registered dealer, so mark it REGULAR. Composition dealers (GSTIN but no
-- output tax) must be re-flagged by hand — they can't be told apart from the
-- GSTIN alone. Shops with no GSTIN stay UNREGISTERED (the default).
UPDATE "users" SET "registration_type" = 'REGULAR' WHERE "shop_gstin" IS NOT NULL;

-- 2. Payment soft-void columns. Payments are no longer hard-deleted; voiding
-- retains the row (audit trail / statutory retention) while excluding it from
-- balances and ledgers.
ALTER TABLE "payments"
  ADD COLUMN "voided_at" TIMESTAMP(3),
  ADD COLUMN "voided_by_id" INTEGER,
  ADD COLUMN "void_reason" TEXT;

ALTER TABLE "payments"
  ADD CONSTRAINT "payments_voided_by_id_fkey"
  FOREIGN KEY ("voided_by_id") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- Speeds up the "live (non-voided) payments for this invoice" aggregate.
CREATE INDEX "payments_invoice_id_voided_at_idx" ON "payments"("invoice_id", "voided_at");
