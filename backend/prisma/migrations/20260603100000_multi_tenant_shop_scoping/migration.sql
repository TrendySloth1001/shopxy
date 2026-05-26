-- Multi-tenant shop scoping (Phase 1 of marketplace migration).
--
-- Adds `shop_id` to every tenant-scoped table that didn't have it
-- (parties, vendors, invoices, challans, purchase_requests, payments,
-- stock_transactions, stock_adjustments, invitations, flash_sales,
-- custom_field_sections, custom_field_definitions), backfills from
-- the singular OWNER's shop, then promotes the column to NOT NULL +
-- FK + indexes. Per-shop unique constraints replace globals.
--
-- Counter is restructured from `(key)` to composite `(shop_id, key)`
-- so each merchant has their own invoice/challan/adjustment number
-- sequence.

-- ── Resolve the backfill default ────────────────────────────────────
-- All pre-migration data belongs to the singular published OWNER's
-- shop. Stored in a session-local temp so all later UPDATEs share it.
--
-- Originally we RAISE EXCEPTION when no OWNER shop existed, but that
-- breaks Prisma's shadow-database replay (the shadow DB is empty so
-- there are no users or shops). For the shadow / fresh-install case the
-- tenant tables are also empty, so the entire backfill is a no-op — we
-- pick a synthetic sentinel id, the UPDATE statements affect zero rows,
-- and the subsequent ALTER … SET NOT NULL trivially holds. The DDL
-- (ADD COLUMN / CREATE INDEX / FK) still runs end-to-end so the schema
-- shape after replay matches a real prod-migrated database.
DO $$
DECLARE
  v_default_shop_id INT;
BEGIN
  SELECT s.id INTO v_default_shop_id
  FROM shops s
  JOIN users u ON u.id = s.owner_user_id
  WHERE u.role = 'OWNER'
  ORDER BY s.is_published DESC, s.id ASC
  LIMIT 1;

  -- Sentinel id for the empty-DB case. We also clear out the only
  -- system-seeded row (the Walk-in Customer party from migration
  -- 20260522110000_walkin_customer_and_legacy_backfill) so the FK
  -- creation later in this script doesn't trip on a row pointing at
  -- shop_id=0. On a real fresh prod install the seed migration will
  -- re-insert the Walk-in Customer on first use; on shadow replay
  -- the schema-only outcome is what matters and the data is thrown
  -- away anyway.
  IF v_default_shop_id IS NULL THEN
    v_default_shop_id := 0;
    DELETE FROM parties WHERE is_system = true AND name = 'Walk-in Customer';
  END IF;

  -- ── parties ───────────────────────────────────────────────────────
  ALTER TABLE parties ADD COLUMN shop_id INT;
  UPDATE parties SET shop_id = v_default_shop_id;
  ALTER TABLE parties ALTER COLUMN shop_id SET NOT NULL;

  -- ── vendors ───────────────────────────────────────────────────────
  ALTER TABLE vendors ADD COLUMN shop_id INT;
  UPDATE vendors SET shop_id = v_default_shop_id;
  ALTER TABLE vendors ALTER COLUMN shop_id SET NOT NULL;

  -- ── invoices ──────────────────────────────────────────────────────
  ALTER TABLE invoices ADD COLUMN shop_id INT;
  UPDATE invoices SET shop_id = v_default_shop_id;
  ALTER TABLE invoices ALTER COLUMN shop_id SET NOT NULL;

  -- ── challans ──────────────────────────────────────────────────────
  ALTER TABLE challans ADD COLUMN shop_id INT;
  UPDATE challans SET shop_id = v_default_shop_id;
  ALTER TABLE challans ALTER COLUMN shop_id SET NOT NULL;

  -- ── purchase_requests ─────────────────────────────────────────────
  ALTER TABLE purchase_requests ADD COLUMN shop_id INT;
  UPDATE purchase_requests SET shop_id = v_default_shop_id;
  ALTER TABLE purchase_requests ALTER COLUMN shop_id SET NOT NULL;

  -- ── payments ──────────────────────────────────────────────────────
  ALTER TABLE payments ADD COLUMN shop_id INT;
  UPDATE payments SET shop_id = v_default_shop_id;
  ALTER TABLE payments ALTER COLUMN shop_id SET NOT NULL;

  -- ── stock_transactions ────────────────────────────────────────────
  ALTER TABLE stock_transactions ADD COLUMN shop_id INT;
  UPDATE stock_transactions SET shop_id = v_default_shop_id;
  ALTER TABLE stock_transactions ALTER COLUMN shop_id SET NOT NULL;

  -- ── stock_adjustments ─────────────────────────────────────────────
  ALTER TABLE stock_adjustments ADD COLUMN shop_id INT;
  UPDATE stock_adjustments SET shop_id = v_default_shop_id;
  ALTER TABLE stock_adjustments ALTER COLUMN shop_id SET NOT NULL;

  -- ── invitations ───────────────────────────────────────────────────
  ALTER TABLE invitations ADD COLUMN shop_id INT;
  -- Invitations may reference the inviter's shop via from_user_id.
  -- Best-effort lookup; fall back to default shop for rows where
  -- the user no longer owns a shop (shouldn't exist in dev but the
  -- guard keeps the migration idempotent).
  UPDATE invitations i
    SET shop_id = COALESCE(
      (SELECT s.id FROM shops s WHERE s.owner_user_id = i.from_user_id),
      v_default_shop_id
    );
  ALTER TABLE invitations ALTER COLUMN shop_id SET NOT NULL;

  -- ── flash_sales ───────────────────────────────────────────────────
  ALTER TABLE flash_sales ADD COLUMN shop_id INT;
  -- Flash sale shopId mirrors its product's shopId.
  UPDATE flash_sales f
    SET shop_id = (SELECT p.shop_id FROM products p WHERE p.id = f.product_id);
  ALTER TABLE flash_sales ALTER COLUMN shop_id SET NOT NULL;

  -- ── custom_field_sections / definitions ───────────────────────────
  ALTER TABLE custom_field_sections ADD COLUMN shop_id INT;
  UPDATE custom_field_sections SET shop_id = v_default_shop_id;
  ALTER TABLE custom_field_sections ALTER COLUMN shop_id SET NOT NULL;

  ALTER TABLE custom_field_definitions ADD COLUMN shop_id INT;
  UPDATE custom_field_definitions SET shop_id = v_default_shop_id;
  ALTER TABLE custom_field_definitions ALTER COLUMN shop_id SET NOT NULL;
END $$;

-- ── Foreign keys ────────────────────────────────────────────────────
ALTER TABLE parties ADD CONSTRAINT parties_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE vendors ADD CONSTRAINT vendors_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE invoices ADD CONSTRAINT invoices_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE challans ADD CONSTRAINT challans_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE purchase_requests ADD CONSTRAINT purchase_requests_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE payments ADD CONSTRAINT payments_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE stock_transactions ADD CONSTRAINT stock_transactions_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE stock_adjustments ADD CONSTRAINT stock_adjustments_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE invitations ADD CONSTRAINT invitations_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE flash_sales ADD CONSTRAINT flash_sales_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE custom_field_sections ADD CONSTRAINT custom_field_sections_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
ALTER TABLE custom_field_definitions ADD CONSTRAINT custom_field_definitions_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;

-- ── Unique constraints: replace globals with per-shop composites ───
-- Invoice number: globally unique → unique per shop.
ALTER TABLE invoices DROP CONSTRAINT IF EXISTS "invoices_invoice_no_key";
DROP INDEX IF EXISTS "invoices_invoice_no_key";
ALTER TABLE invoices ADD CONSTRAINT "invoices_shop_id_invoice_no_key" UNIQUE (shop_id, invoice_no);

-- Challan number: same.
ALTER TABLE challans DROP CONSTRAINT IF EXISTS "challans_challan_no_key";
DROP INDEX IF EXISTS "challans_challan_no_key";
ALTER TABLE challans ADD CONSTRAINT "challans_shop_id_challan_no_key" UNIQUE (shop_id, challan_no);

-- Stock adjustment number: same.
ALTER TABLE stock_adjustments DROP CONSTRAINT IF EXISTS "stock_adjustments_adjustment_no_key";
DROP INDEX IF EXISTS "stock_adjustments_adjustment_no_key";
ALTER TABLE stock_adjustments ADD CONSTRAINT "stock_adjustments_shop_id_adjustment_no_key" UNIQUE (shop_id, adjustment_no);

-- Payment reference number: same.
ALTER TABLE payments DROP CONSTRAINT IF EXISTS "payments_reference_no_key";
DROP INDEX IF EXISTS "payments_reference_no_key";
ALTER TABLE payments ADD CONSTRAINT "payments_shop_id_reference_no_key" UNIQUE (shop_id, reference_no);

-- Purchase-request idempotency key: was (customer_user_id, idempotency_key);
-- becomes (customer_user_id, shop_id, idempotency_key) so the split-cart
-- flow can fire one POST per shop with one shared client UUID.
ALTER TABLE purchase_requests DROP CONSTRAINT IF EXISTS "purchase_requests_user_idempotency_key";
DROP INDEX IF EXISTS "purchase_requests_user_idempotency_key";
ALTER TABLE purchase_requests
  ADD CONSTRAINT "purchase_requests_user_shop_idempotency_key"
  UNIQUE (customer_user_id, shop_id, idempotency_key);

-- Custom field name uniqueness: global → per shop.
ALTER TABLE custom_field_sections DROP CONSTRAINT IF EXISTS "custom_field_sections_name_key";
DROP INDEX IF EXISTS "custom_field_sections_name_key";
ALTER TABLE custom_field_sections ADD CONSTRAINT "custom_field_sections_shop_id_name_key" UNIQUE (shop_id, name);

ALTER TABLE custom_field_definitions DROP CONSTRAINT IF EXISTS "custom_field_definitions_name_key";
DROP INDEX IF EXISTS "custom_field_definitions_name_key";
ALTER TABLE custom_field_definitions ADD CONSTRAINT "custom_field_definitions_shop_id_name_key" UNIQUE (shop_id, name);

-- ── Composite indexes (per-shop list queries) ───────────────────────
-- Drop the old single-column ones that are now redundant alongside
-- the new (shop_id, …) composites.
DROP INDEX IF EXISTS "parties_name_idx";
DROP INDEX IF EXISTS "parties_isActive_idx";
DROP INDEX IF EXISTS "parties_is_active_idx";
DROP INDEX IF EXISTS "vendors_name_idx";
DROP INDEX IF EXISTS "vendors_isActive_idx";
DROP INDEX IF EXISTS "vendors_is_active_idx";
DROP INDEX IF EXISTS "invoices_type_idx";
DROP INDEX IF EXISTS "invoices_status_idx";
DROP INDEX IF EXISTS "invoices_invoiceDate_idx";
DROP INDEX IF EXISTS "invoices_invoice_date_idx";
DROP INDEX IF EXISTS "invoices_financialYear_idx";
DROP INDEX IF EXISTS "invoices_financial_year_idx";
DROP INDEX IF EXISTS "invoices_financialYear_type_idx";
DROP INDEX IF EXISTS "invoices_financial_year_type_idx";
DROP INDEX IF EXISTS "challans_status_idx";
DROP INDEX IF EXISTS "challans_createdAt_idx";
DROP INDEX IF EXISTS "challans_created_at_idx";
DROP INDEX IF EXISTS "purchase_requests_status_createdAt_idx";
DROP INDEX IF EXISTS "purchase_requests_status_created_at_idx";
DROP INDEX IF EXISTS "payments_partyId_paymentDate_idx";
DROP INDEX IF EXISTS "payments_party_id_payment_date_idx";
DROP INDEX IF EXISTS "payments_vendorId_paymentDate_idx";
DROP INDEX IF EXISTS "payments_vendor_id_payment_date_idx";
DROP INDEX IF EXISTS "stock_transactions_productId_createdAt_idx";
DROP INDEX IF EXISTS "stock_transactions_product_id_created_at_idx";
DROP INDEX IF EXISTS "stock_transactions_type_idx";
DROP INDEX IF EXISTS "stock_transactions_reasonCode_idx";
DROP INDEX IF EXISTS "stock_transactions_reason_code_idx";
DROP INDEX IF EXISTS "stock_transactions_createdAt_idx";
DROP INDEX IF EXISTS "stock_transactions_created_at_idx";
DROP INDEX IF EXISTS "stock_adjustments_reasonCode_idx";
DROP INDEX IF EXISTS "stock_adjustments_reason_code_idx";
DROP INDEX IF EXISTS "stock_adjustments_createdAt_idx";
DROP INDEX IF EXISTS "stock_adjustments_created_at_idx";
DROP INDEX IF EXISTS "custom_field_sections_isActive_idx";
DROP INDEX IF EXISTS "custom_field_sections_is_active_idx";
DROP INDEX IF EXISTS "custom_field_sections_sortOrder_idx";
DROP INDEX IF EXISTS "custom_field_sections_sort_order_idx";
DROP INDEX IF EXISTS "custom_field_definitions_isActive_idx";
DROP INDEX IF EXISTS "custom_field_definitions_is_active_idx";
DROP INDEX IF EXISTS "custom_field_definitions_sortOrder_idx";
DROP INDEX IF EXISTS "custom_field_definitions_sort_order_idx";

CREATE INDEX "parties_shop_id_name_idx" ON parties(shop_id, name);
CREATE INDEX "parties_shop_id_is_active_idx" ON parties(shop_id, is_active);
CREATE INDEX "vendors_shop_id_name_idx" ON vendors(shop_id, name);
CREATE INDEX "vendors_shop_id_is_active_idx" ON vendors(shop_id, is_active);
CREATE INDEX "invoices_shop_id_type_idx" ON invoices(shop_id, type);
CREATE INDEX "invoices_shop_id_status_idx" ON invoices(shop_id, status);
CREATE INDEX "invoices_shop_id_invoice_date_idx" ON invoices(shop_id, invoice_date);
CREATE INDEX "invoices_shop_id_financial_year_idx" ON invoices(shop_id, financial_year);
CREATE INDEX "invoices_shop_id_financial_year_type_idx" ON invoices(shop_id, financial_year, type);
CREATE INDEX "challans_shop_id_status_idx" ON challans(shop_id, status);
CREATE INDEX "challans_shop_id_created_at_idx" ON challans(shop_id, created_at);
CREATE INDEX "purchase_requests_shop_id_status_created_at_idx" ON purchase_requests(shop_id, status, created_at);
CREATE INDEX "payments_shop_id_party_id_payment_date_idx" ON payments(shop_id, party_id, payment_date);
CREATE INDEX "payments_shop_id_vendor_id_payment_date_idx" ON payments(shop_id, vendor_id, payment_date);
CREATE INDEX "stock_transactions_shop_id_product_id_created_at_idx" ON stock_transactions(shop_id, product_id, created_at);
CREATE INDEX "stock_transactions_shop_id_type_idx" ON stock_transactions(shop_id, type);
CREATE INDEX "stock_transactions_shop_id_reason_code_idx" ON stock_transactions(shop_id, reason_code);
CREATE INDEX "stock_transactions_shop_id_created_at_idx" ON stock_transactions(shop_id, created_at);
CREATE INDEX "stock_adjustments_shop_id_reason_code_idx" ON stock_adjustments(shop_id, reason_code);
CREATE INDEX "stock_adjustments_shop_id_created_at_idx" ON stock_adjustments(shop_id, created_at);
CREATE INDEX "invitations_shop_id_status_created_at_idx" ON invitations(shop_id, status, created_at);
CREATE INDEX "flash_sales_shop_id_is_active_idx" ON flash_sales(shop_id, is_active);
CREATE INDEX "custom_field_sections_shop_id_is_active_idx" ON custom_field_sections(shop_id, is_active);
CREATE INDEX "custom_field_sections_shop_id_sort_order_idx" ON custom_field_sections(shop_id, sort_order);
CREATE INDEX "custom_field_definitions_shop_id_is_active_idx" ON custom_field_definitions(shop_id, is_active);
CREATE INDEX "custom_field_definitions_shop_id_sort_order_idx" ON custom_field_definitions(shop_id, sort_order);

-- ── Counter: restructure to (shop_id, key) composite primary key ────
-- Existing counters belong to the default shop; they're invoice/challan
-- number counters that should reset per shop going forward.
ALTER TABLE counters ADD COLUMN shop_id INT;
UPDATE counters SET shop_id = (
  SELECT s.id FROM shops s
  JOIN users u ON u.id = s.owner_user_id
  WHERE u.role = 'OWNER'
  ORDER BY s.is_published DESC, s.id ASC
  LIMIT 1
);
ALTER TABLE counters ALTER COLUMN shop_id SET NOT NULL;
ALTER TABLE counters DROP CONSTRAINT counters_pkey;
ALTER TABLE counters ADD PRIMARY KEY (shop_id, key);
ALTER TABLE counters ADD CONSTRAINT counters_shop_id_fkey
  FOREIGN KEY (shop_id) REFERENCES shops(id) ON DELETE CASCADE;
