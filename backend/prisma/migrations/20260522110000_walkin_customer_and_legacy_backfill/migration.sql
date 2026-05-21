-- 1. Add isSystem flag to parties.
ALTER TABLE "parties"
  ADD COLUMN IF NOT EXISTS "is_system" BOOLEAN NOT NULL DEFAULT false;

-- 2. Seed a system Walk-in Customer party. Idempotent — upserted by name.
INSERT INTO "parties" ("name", "is_system", "is_active", "created_at", "updated_at")
SELECT 'Walk-in Customer', true, true, NOW(), NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM "parties" WHERE "name" = 'Walk-in Customer'
);
-- If a user-created "Walk-in Customer" already exists, promote it to system.
UPDATE "parties"
SET "is_system" = true
WHERE "name" = 'Walk-in Customer' AND "is_system" = false;

-- 3. F7: backfill stock_before / stock_after on legacy ledger rows that
--    have NULL snapshots (pre-phase-1 rows). Walk each product's history
--    chronologically and replay the running balance.
DO $$
DECLARE
  prod_id INTEGER;
  running NUMERIC;
  row_rec RECORD;
BEGIN
  FOR prod_id IN SELECT DISTINCT product_id FROM stock_transactions
                  WHERE stock_before IS NULL OR stock_after IS NULL
  LOOP
    running := 0;
    FOR row_rec IN
      SELECT id, direction, quantity, stock_before, stock_after
      FROM stock_transactions
      WHERE product_id = prod_id
      ORDER BY created_at ASC, id ASC
    LOOP
      IF row_rec.stock_before IS NULL THEN
        -- Snap: the row's effect on running balance.
        IF row_rec.direction = 'IN' THEN
          UPDATE stock_transactions
          SET stock_before = running,
              stock_after = running + row_rec.quantity
          WHERE id = row_rec.id;
          running := running + row_rec.quantity;
        ELSE
          UPDATE stock_transactions
          SET stock_before = running,
              stock_after = running - row_rec.quantity
          WHERE id = row_rec.id;
          running := running - row_rec.quantity;
        END IF;
      ELSE
        -- Row already has a snapshot — trust it and resume from there.
        running := row_rec.stock_after;
      END IF;
    END LOOP;
  END LOOP;
END $$;
