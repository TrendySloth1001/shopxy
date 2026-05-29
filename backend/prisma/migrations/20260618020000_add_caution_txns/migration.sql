-- Refundable caution / security deposits held by a shop against a party.
-- Additive only: a new table plus its FKs. Nothing existing is altered, so
-- every party starts with a zero balance and no backfill is required.

CREATE TABLE "caution_txns" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "party_id" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "mode" TEXT,
    "mode_reference" TEXT,
    "invoice_id" INTEGER,
    "payment_id" INTEGER,
    "note" TEXT,
    "created_by_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "caution_txns_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "caution_txns_shop_id_party_id_created_at_idx" ON "caution_txns"("shop_id", "party_id", "created_at");

ALTER TABLE "caution_txns" ADD CONSTRAINT "caution_txns_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "caution_txns" ADD CONSTRAINT "caution_txns_party_id_fkey" FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "caution_txns" ADD CONSTRAINT "caution_txns_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "invoices"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "caution_txns" ADD CONSTRAINT "caution_txns_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "payments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "caution_txns" ADD CONSTRAINT "caution_txns_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
