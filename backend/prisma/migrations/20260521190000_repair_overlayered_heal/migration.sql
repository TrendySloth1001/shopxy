-- Patch for an earlier draft of phase-2 that added a new cost_layer for
-- every drift heal — including products that already had layers. Result
-- was layer_total > derived for those products.
--
-- Drop the heal-only layers (those linked to a "Phase-2 reconciliation"
-- ledger row) when their product still has another layer that covers the
-- derived stock.

DELETE FROM cost_layers cl
WHERE cl.ledger_entry_id IN (
  SELECT id FROM stock_transactions WHERE note = 'Phase-2 reconciliation: drift heal'
)
AND EXISTS (
  SELECT 1
  FROM cost_layers other
  WHERE other.product_id = cl.product_id
    AND other.id <> cl.id
    AND other.qty_remaining > 0
)
AND (
  SELECT SUM(qty_remaining) FROM cost_layers WHERE product_id = cl.product_id
) > (
  SELECT stock_quantity FROM products WHERE id = cl.product_id
);
