-- NOTE: ADDITIVE ONLY (two new tables + indexes + FKs). The `migrate diff`
-- output also produced an unrelated `ALTER TABLE products ALTER COLUMN
-- search_vector DROP DEFAULT` line — pre-existing DB/schema drift on a table
-- this change does not touch — which was stripped per the additive-only rule
-- (ROUTE_SPLIT_DESIGN.md §8). Do not re-add it.

-- CreateTable
CREATE TABLE "linked_accounts" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "provider" TEXT NOT NULL DEFAULT 'RAZORPAY',
    "provider_account_id" TEXT,
    "kyc_status" TEXT NOT NULL DEFAULT 'CREATED',
    "payouts_enabled" BOOLEAN NOT NULL DEFAULT false,
    "email" TEXT,
    "contact_name" TEXT,
    "business_type" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "linked_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gateway_transfers" (
    "id" SERIAL NOT NULL,
    "gateway_payment_id" INTEGER NOT NULL,
    "purchase_request_id" INTEGER NOT NULL,
    "linked_account_id" INTEGER,
    "provider_account_id" TEXT,
    "amount" DECIMAL(12,2) NOT NULL,
    "provider_transfer_ref" TEXT,
    "idempotency_key" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'HELD',
    "hold_until" TIMESTAMP(3),
    "released_at" TIMESTAMP(3),
    "reversed_at" TIMESTAMP(3),
    "reversed_amount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "failure_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gateway_transfers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "linked_accounts_shop_id_key" ON "linked_accounts"("shop_id");

-- CreateIndex
CREATE INDEX "linked_accounts_provider_provider_account_id_idx" ON "linked_accounts"("provider", "provider_account_id");

-- CreateIndex
CREATE INDEX "gateway_transfers_status_hold_until_idx" ON "gateway_transfers"("status", "hold_until");

-- CreateIndex
CREATE INDEX "gateway_transfers_purchase_request_id_idx" ON "gateway_transfers"("purchase_request_id");

-- CreateIndex
CREATE INDEX "gateway_transfers_provider_transfer_ref_idx" ON "gateway_transfers"("provider_transfer_ref");

-- CreateIndex
CREATE UNIQUE INDEX "gateway_transfers_gateway_payment_id_purchase_request_id_key" ON "gateway_transfers"("gateway_payment_id", "purchase_request_id");

-- AddForeignKey
ALTER TABLE "linked_accounts" ADD CONSTRAINT "linked_accounts_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gateway_transfers" ADD CONSTRAINT "gateway_transfers_purchase_request_id_fkey" FOREIGN KEY ("purchase_request_id") REFERENCES "purchase_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gateway_transfers" ADD CONSTRAINT "gateway_transfers_linked_account_id_fkey" FOREIGN KEY ("linked_account_id") REFERENCES "linked_accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

