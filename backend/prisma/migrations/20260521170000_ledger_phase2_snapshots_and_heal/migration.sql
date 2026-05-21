-- ────────────────────────────────────────────────────────────────────
-- Ledger phase 2: identity snapshots + drift heal
-- ────────────────────────────────────────────────────────────────────

-- 1. Invoice gets vendor-side identity snapshots, mirroring the existing
--    customerName/customerPhone/customerGstin trio. Survives vendor delete.
ALTER TABLE "invoices"
  ADD COLUMN IF NOT EXISTS "vendor_name"  TEXT,
  ADD COLUMN IF NOT EXISTS "vendor_phone" TEXT,
  ADD COLUMN IF NOT EXISTS "vendor_gstin" TEXT;

-- Backfill existing invoices from the vendor join (where vendor still exists).
UPDATE "invoices" i
SET "vendor_name"  = v."name",
    "vendor_phone" = v."phone",
    "vendor_gstin" = v."gstin"
FROM "vendors" v
WHERE i."vendor_id" = v."id" AND i."vendor_name" IS NULL;

-- 2. StockTransaction gets a generic counterparty snapshot pair. One column
--    pair covers both vendor (IN) and party (OUT) — the direction tells you
--    which it is. Survives vendor/party delete.
ALTER TABLE "stock_transactions"
  ADD COLUMN IF NOT EXISTS "counterparty_name"  TEXT,
  ADD COLUMN IF NOT EXISTS "counterparty_gstin" TEXT;

-- Backfill vendor side from existing vendor_id (IN rows).
UPDATE "stock_transactions" st
SET "counterparty_name"  = v."name",
    "counterparty_gstin" = v."gstin"
FROM "vendors" v
WHERE st."vendor_id" = v."id" AND st."counterparty_name" IS NULL;

-- Backfill from existing supplier_name (legacy free-text) when no vendor row.
UPDATE "stock_transactions"
SET "counterparty_name" = "supplier_name"
WHERE "counterparty_name" IS NULL AND "supplier_name" IS NOT NULL;

-- Backfill from invoice for INVOICE-sourced rows (now that snapshots exist).
UPDATE "stock_transactions" st
SET "counterparty_name" = COALESCE(i."customer_name", i."vendor_name"),
    "counterparty_gstin" = COALESCE(i."customer_gstin", i."vendor_gstin")
FROM "invoices" i
WHERE st."source_type" = 'INVOICE'
  AND st."source_id" = i."id"
  AND st."counterparty_name" IS NULL;

-- Backfill from challan (party_name is already snapshotted on the challan table).
UPDATE "stock_transactions" st
SET "counterparty_name" = c."party_name"
FROM "challans" c
WHERE st."source_type" = 'CHALLAN'
  AND st."source_id" = c."id"
  AND st."counterparty_name" IS NULL;

-- ────────────────────────────────────────────────────────────────────
-- 3. F2 heal: products whose ledger sum != stock_quantity. Insert a
--    catch-up RECOUNT row + a matching cost_layer for any drift, so the
--    invariant SUM(±qty)=stock_quantity holds going forward.
--
--    Anything left over from the phase-1 migration (legacy OUTs that
--    weren't accounted for in the OPENING) gets reconciled here.
-- ────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  rec RECORD;
  new_ledger_id INTEGER;
  drift NUMERIC;
BEGIN
  FOR rec IN
    SELECT p.id AS product_id,
           p.stock_quantity::numeric AS derived,
           p.purchase_price::numeric AS purchase_price,
           COALESCE(SUM(
             CASE WHEN st.direction = 'IN' THEN st.quantity::numeric
                  ELSE -st.quantity::numeric END
           ), 0) AS ledger_sum
    FROM products p
    LEFT JOIN stock_transactions st ON st.product_id = p.id
    GROUP BY p.id
  LOOP
    drift := rec.derived - rec.ledger_sum;
    IF drift = 0 THEN CONTINUE; END IF;

    IF drift > 0 THEN
      -- Need to add to ledger. Post a RECOUNT IN and create a layer.
      INSERT INTO stock_transactions (
        product_id, direction, reason_code, source_type, source_id,
        quantity, unit_cost, total_value, stock_before, stock_after,
        type, note, created_at
      ) VALUES (
        rec.product_id, 'IN', 'RECOUNT', 'OPENING', NULL,
        drift, rec.purchase_price, drift * rec.purchase_price,
        rec.derived - drift, rec.derived,
        'ADJUSTMENT',
        'Phase-2 reconciliation: drift heal',
        NOW()
      )
      RETURNING id INTO new_ledger_id;

      INSERT INTO cost_layers (
        product_id, qty_received, qty_remaining, unit_cost,
        source_type, source_id, ledger_entry_id, created_at
      ) VALUES (
        rec.product_id, drift, drift, rec.purchase_price,
        'OPENING', NULL, new_ledger_id, NOW()
      );
    ELSE
      -- Ledger is ahead of derived; post a RECOUNT OUT and shrink layers.
      INSERT INTO stock_transactions (
        product_id, direction, reason_code, source_type, source_id,
        quantity, unit_cost, total_value, stock_before, stock_after,
        type, note, created_at
      ) VALUES (
        rec.product_id, 'OUT', 'RECOUNT', 'OPENING', NULL,
        -drift, NULL, NULL,
        rec.derived + (-drift), rec.derived,
        'ADJUSTMENT',
        'Phase-2 reconciliation: drift heal',
        NOW()
      );
      -- Best-effort layer shrink (oldest first). We don't track consumption
      -- rows for this reconciliation — it's an audit reset, not a sale.
      UPDATE cost_layers
      SET qty_remaining = GREATEST(qty_remaining - (-drift), 0)
      WHERE product_id = rec.product_id;
    END IF;
  END LOOP;
END $$;
