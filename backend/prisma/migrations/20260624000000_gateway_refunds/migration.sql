-- Real-money refund-to-source persistence. Additive only — no destructive
-- changes to existing tables. Idempotent (IF NOT EXISTS / guarded ADD COLUMN)
-- so it is safe to (re)apply against a drifted dev database via `migrate deploy`.
--
-- A captured online payment (card/UPI/netbanking) MUST be reversed to the
-- original instrument, never silently converted to wallet/store credit (RBI
-- "refund to source"; Consumer Protection (E-Commerce) Rules 2020, Rule 4(7)).
-- These tables are what the gateway refund engine reads/writes.

-- Cap-tracking column on the captured intent: cumulative real money already
-- refunded to source. The engine refunds at most (amount - amount_refunded).
ALTER TABLE "gateway_payments"
  ADD COLUMN IF NOT EXISTS "amount_refunded" DECIMAL(12,2) NOT NULL DEFAULT 0;

-- Resolve "the captured payment for this order/sale" from (target_type, target_id).
CREATE INDEX IF NOT EXISTS "gateway_payments_target_type_target_id_idx"
  ON "gateway_payments" ("target_type", "target_id");

-- One row per refund-to-source attempt against a captured GatewayPayment.
CREATE TABLE IF NOT EXISTS "gateway_refunds" (
  "id" SERIAL NOT NULL,
  "gateway_payment_id" INTEGER NOT NULL,
  "provider" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "amount" DECIMAL(12,2) NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'INR',
  "provider_refund_ref" TEXT,
  "source_type" TEXT NOT NULL,
  "source_id" INTEGER NOT NULL,
  "reason" TEXT,
  "idempotency_key" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "gateway_refunds_pkey" PRIMARY KEY ("id")
);

-- Idempotency gate: a retried return/cancel re-uses the existing refund row.
CREATE UNIQUE INDEX IF NOT EXISTS "gateway_refunds_idempotency_key_key"
  ON "gateway_refunds" ("idempotency_key");

-- Children of one captured payment (partial refunds, audit).
CREATE INDEX IF NOT EXISTS "gateway_refunds_gateway_payment_id_idx"
  ON "gateway_refunds" ("gateway_payment_id");

-- refund.processed / refund.failed webhook → resolve the row by provider ref.
CREATE INDEX IF NOT EXISTS "gateway_refunds_provider_provider_refund_ref_idx"
  ON "gateway_refunds" ("provider", "provider_refund_ref");

-- Trace a refund back to its triggering domain event (RETURN / CANCEL).
CREATE INDEX IF NOT EXISTS "gateway_refunds_source_type_source_id_idx"
  ON "gateway_refunds" ("source_type", "source_id");
