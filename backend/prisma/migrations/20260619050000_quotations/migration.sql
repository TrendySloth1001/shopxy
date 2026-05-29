-- Merchant-built quotations sent to a linked customer for acceptance.
-- On accept a quotation spawns a confirmed sale invoice. Additive only.

CREATE TABLE "quotations" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "party_id" INTEGER NOT NULL,
    "quotation_no" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "items" JSONB NOT NULL,
    "subtotal" DECIMAL(14,2) NOT NULL,
    "tax_amount" DECIMAL(14,2) NOT NULL,
    "total" DECIMAL(14,2) NOT NULL,
    "note" TEXT,
    "place_of_supply_state_code" TEXT,
    "created_by_id" INTEGER,
    "responded_at" TIMESTAMP(3),
    "decline_note" TEXT,
    "invoice_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quotations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "quotations_invoice_id_key" ON "quotations"("invoice_id");
CREATE UNIQUE INDEX "quotations_shop_id_quotation_no_key" ON "quotations"("shop_id", "quotation_no");
CREATE INDEX "quotations_shop_id_status_created_at_idx" ON "quotations"("shop_id", "status", "created_at");
CREATE INDEX "quotations_party_id_status_idx" ON "quotations"("party_id", "status");

ALTER TABLE "quotations" ADD CONSTRAINT "quotations_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_party_id_fkey" FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "quotations" ADD CONSTRAINT "quotations_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "invoices"("id") ON DELETE SET NULL ON UPDATE CASCADE;
