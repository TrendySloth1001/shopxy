-- =================================================================
-- Phase 1: Stock Ledger Backbone
--
-- Adds the ledger columns to stock_transactions, creates the new
-- header tables (stock_adjustments), and the FIFO cost-layer tables
-- (cost_layers + cost_consumptions).
--
-- Backfill strategy: legacy rows get direction/reasonCode/sourceType
-- derived from `type`. Pre-existing stock is captured as a single
-- OPENING cost layer per product, sized to the current stockQuantity
-- × current purchasePrice. Historical OUT rows are NOT retro-linked
-- to layers (their unitCost stays NULL). Ledger entries posted from
-- this migration onward are fully linked.
-- =================================================================

-- ── stock_transactions: new ledger columns ─────────────────────────
ALTER TABLE "stock_transactions"
  ADD COLUMN "direction" TEXT,
  ADD COLUMN "reason_code" TEXT,
  ADD COLUMN "source_type" TEXT NOT NULL DEFAULT 'MANUAL',
  ADD COLUMN "source_id" INTEGER,
  ADD COLUMN "source_line_id" INTEGER,
  ADD COLUMN "unit_cost" DECIMAL(12,4),
  ADD COLUMN "total_value" DECIMAL(14,2),
  ADD COLUMN "stock_before" DECIMAL(12,3),
  ADD COLUMN "stock_after" DECIMAL(12,3),
  ADD COLUMN "reverses_id" INTEGER,
  ADD COLUMN "created_by_id" INTEGER,
  ADD COLUMN "idempotency_key" TEXT;

-- Backfill direction + reasonCode for legacy rows from the old `type` enum.
UPDATE "stock_transactions"
SET
  "direction" = CASE
    WHEN "type" = 'STOCK_IN' THEN 'IN'
    WHEN "type" = 'STOCK_OUT' THEN 'OUT'
    ELSE 'OUT'
  END,
  "reason_code" = CASE
    WHEN "type" = 'STOCK_IN' THEN 'PURCHASE'
    WHEN "type" = 'STOCK_OUT' THEN 'SHRINKAGE'
    WHEN "type" = 'ADJUSTMENT' THEN 'RECOUNT'
    ELSE 'SHRINKAGE'
  END
WHERE "direction" IS NULL;

ALTER TABLE "stock_transactions"
  ALTER COLUMN "direction" SET NOT NULL,
  ALTER COLUMN "reason_code" SET NOT NULL;

CREATE UNIQUE INDEX "stock_transactions_reverses_id_key"
  ON "stock_transactions"("reverses_id");
CREATE UNIQUE INDEX "stock_transactions_idempotency_key_key"
  ON "stock_transactions"("idempotency_key");
CREATE INDEX "stock_transactions_reason_code_idx"
  ON "stock_transactions"("reason_code");
CREATE INDEX "stock_transactions_source_type_source_id_idx"
  ON "stock_transactions"("source_type", "source_id");
CREATE INDEX "stock_transactions_product_id_created_at_idx"
  ON "stock_transactions"("product_id", "created_at");

ALTER TABLE "stock_transactions"
  ADD CONSTRAINT "stock_transactions_reverses_id_fkey"
  FOREIGN KEY ("reverses_id") REFERENCES "stock_transactions"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "stock_transactions"
  ADD CONSTRAINT "stock_transactions_created_by_id_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- ── cost_layers (FIFO) ─────────────────────────────────────────────
CREATE TABLE "cost_layers" (
  "id" SERIAL PRIMARY KEY,
  "product_id" INTEGER NOT NULL,
  "qty_received" DECIMAL(12,3) NOT NULL,
  "qty_remaining" DECIMAL(12,3) NOT NULL,
  "unit_cost" DECIMAL(12,4) NOT NULL,
  "source_type" TEXT NOT NULL,
  "source_id" INTEGER,
  "ledger_entry_id" INTEGER NOT NULL,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "cost_layers_product_id_fkey"
    FOREIGN KEY ("product_id") REFERENCES "products"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "cost_layers_ledger_entry_id_fkey"
    FOREIGN KEY ("ledger_entry_id") REFERENCES "stock_transactions"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "cost_layers_ledger_entry_id_key"
  ON "cost_layers"("ledger_entry_id");
CREATE INDEX "cost_layers_product_id_created_at_idx"
  ON "cost_layers"("product_id", "created_at");
CREATE INDEX "cost_layers_product_id_qty_remaining_idx"
  ON "cost_layers"("product_id", "qty_remaining");

-- ── cost_consumptions ──────────────────────────────────────────────
CREATE TABLE "cost_consumptions" (
  "id" SERIAL PRIMARY KEY,
  "layer_id" INTEGER NOT NULL,
  "ledger_entry_id" INTEGER NOT NULL,
  "qty_consumed" DECIMAL(12,3) NOT NULL,
  "unit_cost" DECIMAL(12,4) NOT NULL,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "cost_consumptions_layer_id_fkey"
    FOREIGN KEY ("layer_id") REFERENCES "cost_layers"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "cost_consumptions_ledger_entry_id_fkey"
    FOREIGN KEY ("ledger_entry_id") REFERENCES "stock_transactions"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "cost_consumptions_layer_id_idx"
  ON "cost_consumptions"("layer_id");
CREATE INDEX "cost_consumptions_ledger_entry_id_idx"
  ON "cost_consumptions"("ledger_entry_id");

-- ── stock_adjustments + items ──────────────────────────────────────
CREATE TABLE "stock_adjustments" (
  "id" SERIAL PRIMARY KEY,
  "adjustment_no" TEXT NOT NULL,
  "reason_code" TEXT NOT NULL,
  "direction" TEXT NOT NULL,
  "note" TEXT,
  "created_by_id" INTEGER,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "stock_adjustments_created_by_id_fkey"
    FOREIGN KEY ("created_by_id") REFERENCES "users"("id")
    ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "stock_adjustments_adjustment_no_key"
  ON "stock_adjustments"("adjustment_no");
CREATE INDEX "stock_adjustments_reason_code_idx"
  ON "stock_adjustments"("reason_code");
CREATE INDEX "stock_adjustments_created_at_idx"
  ON "stock_adjustments"("created_at");

CREATE TABLE "stock_adjustment_items" (
  "id" SERIAL PRIMARY KEY,
  "adjustment_id" INTEGER NOT NULL,
  "product_id" INTEGER NOT NULL,
  "product_name" TEXT NOT NULL,
  "product_sku" TEXT NOT NULL,
  "unit" TEXT NOT NULL DEFAULT 'PCS',
  "quantity" DECIMAL(12,3) NOT NULL,
  "unit_cost" DECIMAL(12,4),
  "note" TEXT,

  CONSTRAINT "stock_adjustment_items_adjustment_id_fkey"
    FOREIGN KEY ("adjustment_id") REFERENCES "stock_adjustments"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "stock_adjustment_items_product_id_fkey"
    FOREIGN KEY ("product_id") REFERENCES "products"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX "stock_adjustment_items_adjustment_id_idx"
  ON "stock_adjustment_items"("adjustment_id");
CREATE INDEX "stock_adjustment_items_product_id_idx"
  ON "stock_adjustment_items"("product_id");

-- ── Opening-balance backfill ───────────────────────────────────────
-- For every product with stock on hand right now, emit an OPENING
-- ledger row AND a cost layer sized to current stockQuantity ×
-- current purchasePrice. This way, FIFO has a baseline to consume
-- against. Historical STOCK_IN rows are not retroactively layered.
DO $$
DECLARE
  prod RECORD;
  ledger_id INTEGER;
BEGIN
  FOR prod IN
    SELECT id, stock_quantity, purchase_price
    FROM products
    WHERE stock_quantity > 0
  LOOP
    INSERT INTO stock_transactions (
      product_id, direction, reason_code, source_type, source_id,
      quantity, unit_cost, total_value,
      stock_before, stock_after,
      type, note, created_at
    ) VALUES (
      prod.id, 'IN', 'OPENING', 'OPENING', NULL,
      prod.stock_quantity, prod.purchase_price,
      ROUND(prod.stock_quantity * prod.purchase_price, 2),
      0, prod.stock_quantity,
      'STOCK_IN',
      'Opening balance — auto-generated by ledger migration',
      CURRENT_TIMESTAMP
    )
    RETURNING id INTO ledger_id;

    INSERT INTO cost_layers (
      product_id, qty_received, qty_remaining, unit_cost,
      source_type, source_id, ledger_entry_id, created_at
    ) VALUES (
      prod.id, prod.stock_quantity, prod.stock_quantity,
      prod.purchase_price, 'OPENING', NULL, ledger_id, CURRENT_TIMESTAMP
    );
  END LOOP;
END $$;
