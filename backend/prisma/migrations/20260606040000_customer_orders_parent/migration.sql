-- Introduce a parent CustomerOrder that owns N PurchaseRequest children
-- (one per shop). One row = one checkout submission; the customer sees
-- it as "order #N" while merchants still see only their own child slice
-- in their inbox.
--
-- This migration:
--   1. Creates the new customer_orders table.
--   2. Adds purchase_requests.customer_order_id (NULLABLE for backfill).
--   3. Backfills: one parent CustomerOrder per existing PurchaseRequest
--      (preserving identity / address / total / timestamps). We do not
--      copy idempotency_key onto the parent — keys served their dedup
--      purpose at submission time, and propagating them risks
--      collisions on the new (customer_user_id, idempotency_key) unique
--      when several legacy PRs share a key.
--   4. Promotes purchase_requests.customer_order_id to NOT NULL + FK.
--   5. Retires the per-PR idempotency_key column + its surviving
--      unique; the parent owns idempotency from here on.

-- ── 1. Parent table ────────────────────────────────────────────────
CREATE TABLE "customer_orders" (
  "id"               SERIAL PRIMARY KEY,
  "customer_user_id" INTEGER NOT NULL,
  "customer_name"    TEXT NOT NULL,
  "customer_phone"   TEXT,
  "customer_email"   TEXT,
  "customer_address" TEXT,
  "note"             TEXT,
  "estimated_total"  DECIMAL(12, 2) NOT NULL DEFAULT 0,
  "idempotency_key"  TEXT,
  "created_at"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "customer_orders_customer_user_fk"
    FOREIGN KEY ("customer_user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX "customer_orders_user_idempotency_key"
  ON "customer_orders"("customer_user_id", "idempotency_key");
CREATE INDEX "customer_orders_customer_user_id_created_at_idx"
  ON "customer_orders"("customer_user_id", "created_at");

-- ── 2. Nullable child FK ──────────────────────────────────────────
ALTER TABLE "purchase_requests"
  ADD COLUMN "customer_order_id" INTEGER;

-- ── 3. Backfill: 1:1 parent per legacy child ──────────────────────
DO $$
DECLARE
  pr_row RECORD;
  new_parent_id INT;
BEGIN
  FOR pr_row IN
    SELECT "id", "customer_user_id", "customer_name", "customer_phone",
           "customer_email", "customer_address", "note", "estimated_total",
           "created_at", "updated_at"
    FROM "purchase_requests"
    WHERE "customer_order_id" IS NULL
    ORDER BY "id"
  LOOP
    INSERT INTO "customer_orders" (
      "customer_user_id", "customer_name", "customer_phone",
      "customer_email", "customer_address", "note", "estimated_total",
      "idempotency_key", "created_at", "updated_at"
    ) VALUES (
      pr_row."customer_user_id", pr_row."customer_name", pr_row."customer_phone",
      pr_row."customer_email", pr_row."customer_address", pr_row."note",
      pr_row."estimated_total",
      NULL,
      pr_row."created_at", pr_row."updated_at"
    )
    RETURNING "id" INTO new_parent_id;
    UPDATE "purchase_requests"
      SET "customer_order_id" = new_parent_id
      WHERE "id" = pr_row."id";
  END LOOP;
END $$;

-- ── 4. Promote to NOT NULL + FK + index ───────────────────────────
ALTER TABLE "purchase_requests"
  ALTER COLUMN "customer_order_id" SET NOT NULL;

ALTER TABLE "purchase_requests"
  ADD CONSTRAINT "purchase_requests_customer_order_fk"
  FOREIGN KEY ("customer_order_id") REFERENCES "customer_orders"("id")
  ON DELETE CASCADE;

CREATE INDEX "purchase_requests_customer_order_id_idx"
  ON "purchase_requests"("customer_order_id");

-- ── 5. Retire the per-PR idempotency key ──────────────────────────
ALTER TABLE "purchase_requests"
  DROP CONSTRAINT IF EXISTS "purchase_requests_user_shop_idempotency_key";
DROP INDEX IF EXISTS "purchase_requests_user_shop_idempotency_key";

ALTER TABLE "purchase_requests"
  DROP COLUMN IF EXISTS "idempotency_key";
