-- Partial unique on (shop_id, linked_user_id) WHERE linked_user_id IS NOT NULL.
--
-- Prevents a single user being linked twice to the same shop as a Party
-- or Vendor. Without this, a customer who accepts multiple invites from
-- the same merchant (or a race in `respond`) ends up with duplicate
-- linked rows, each granting independent ledger access via
-- `/me/parties/:id/invoices`.
--
-- Partial (WHERE linked_user_id IS NOT NULL) so we keep allowing many
-- party rows with NULL linkedUserId (the merchant's own private contacts).
--
-- NOT existing-conflict-tolerant: if the table currently holds dupes,
-- the index creation will fail. The audit hasn't surfaced any in this
-- codebase but if a prod env disagrees, run this preparation step first:
--   DELETE FROM parties p
--    WHERE p.linked_user_id IS NOT NULL
--      AND EXISTS (
--        SELECT 1 FROM parties q
--         WHERE q.shop_id = p.shop_id
--           AND q.linked_user_id = p.linked_user_id
--           AND q.id < p.id
--      );
-- (mirrors for vendors).

CREATE UNIQUE INDEX "parties_shop_id_linked_user_id_unique"
  ON "parties" ("shop_id", "linked_user_id")
  WHERE "linked_user_id" IS NOT NULL;

CREATE UNIQUE INDEX "vendors_shop_id_linked_user_id_unique"
  ON "vendors" ("shop_id", "linked_user_id")
  WHERE "linked_user_id" IS NOT NULL;
