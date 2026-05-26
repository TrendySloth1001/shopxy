-- Every invoice represents either a purchase (vendor) or a sale (party),
-- never both and never neither. The Prisma schema marks both FKs nullable
-- (line 668-671) and the controller layer is supposed to enforce "exactly
-- one"; this constraint moves that invariant into the database so bad
-- writes from a misbehaving client or a stray script can't accumulate.
--
-- Added NOT VALID so the constraint only applies to new/updated rows.
-- Existing rows that violate the rule (if any) keep flowing; a follow-up
-- audit can clean them up and then run
--   ALTER TABLE invoices VALIDATE CONSTRAINT invoices_vendor_party_xor;
-- to retroactively enforce.
ALTER TABLE "invoices"
  ADD CONSTRAINT "invoices_vendor_party_xor"
  CHECK (((vendor_id IS NOT NULL)::int + (party_id IS NOT NULL)::int) = 1)
  NOT VALID;
