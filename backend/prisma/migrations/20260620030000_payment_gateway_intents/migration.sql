-- Provider-agnostic online-payment seam (Razorpay first; multi-gateway ready).
-- Additive only: two new tables, no FKs, nothing existing is altered — so no
-- backfill and no impact on current data. See PAYMENT_GATEWAY_ARCHITECTURE.md
-- and modules/payment-gateway/.

-- CreateTable
CREATE TABLE "gateway_payments" (
    "id" SERIAL NOT NULL,
    "provider" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'CREATED',
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "target_type" TEXT NOT NULL,
    "target_id" INTEGER NOT NULL,
    "shop_id" INTEGER,
    "customer_user_id" INTEGER,
    "provider_order_ref" TEXT,
    "provider_payment_ref" TEXT,
    "idempotency_key" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gateway_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gateway_webhook_events" (
    "id" SERIAL NOT NULL,
    "provider" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "processed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gateway_webhook_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "gateway_payments_provider_provider_order_ref_idx" ON "gateway_payments"("provider", "provider_order_ref");

-- CreateIndex
CREATE INDEX "gateway_payments_provider_provider_payment_ref_idx" ON "gateway_payments"("provider", "provider_payment_ref");

-- CreateIndex
CREATE INDEX "gateway_payments_status_target_type_idx" ON "gateway_payments"("status", "target_type");

-- CreateIndex
CREATE UNIQUE INDEX "gateway_payments_customer_user_id_idempotency_key_key" ON "gateway_payments"("customer_user_id", "idempotency_key");

-- CreateIndex
CREATE UNIQUE INDEX "gateway_webhook_events_provider_event_id_key" ON "gateway_webhook_events"("provider", "event_id");
