-- Caution phase 2: party-initiated requests, forfeiture, documentary trail.
-- Additive only — new nullable columns on caution_txns + a new caution_requests
-- table. Nothing existing is altered; no backfill needed.

-- 1. Documentary + forfeiture columns on the existing ledger.
ALTER TABLE "caution_txns" ADD COLUMN "receipt_no" TEXT;
ALTER TABLE "caution_txns" ADD COLUMN "gst_treatment" TEXT;

-- 2. Party-initiated caution requests (request -> merchant approves).
CREATE TABLE "caution_requests" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "party_id" INTEGER NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "mode" TEXT,
    "mode_reference" TEXT,
    "note" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "channel" TEXT NOT NULL DEFAULT 'MANUAL',
    "provider" TEXT,
    "provider_ref" TEXT,
    "requested_by_id" INTEGER,
    "reviewed_by_id" INTEGER,
    "reviewed_at" TIMESTAMP(3),
    "review_note" TEXT,
    "caution_txn_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "caution_requests_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "caution_requests_caution_txn_id_key" ON "caution_requests"("caution_txn_id");
CREATE INDEX "caution_requests_shop_id_status_created_at_idx" ON "caution_requests"("shop_id", "status", "created_at");
CREATE INDEX "caution_requests_party_id_status_idx" ON "caution_requests"("party_id", "status");

ALTER TABLE "caution_requests" ADD CONSTRAINT "caution_requests_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "caution_requests" ADD CONSTRAINT "caution_requests_party_id_fkey" FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "caution_requests" ADD CONSTRAINT "caution_requests_requested_by_id_fkey" FOREIGN KEY ("requested_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "caution_requests" ADD CONSTRAINT "caution_requests_reviewed_by_id_fkey" FOREIGN KEY ("reviewed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "caution_requests" ADD CONSTRAINT "caution_requests_caution_txn_id_fkey" FOREIGN KEY ("caution_txn_id") REFERENCES "caution_txns"("id") ON DELETE SET NULL ON UPDATE CASCADE;
