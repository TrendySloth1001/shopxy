-- Drop the platform-wide bank-offer catalogue (feature removed).
--
-- DESTRUCTIVE: discards every stored offer, and nothing can recreate them.
-- `pg_dump -t platform_bank_offers` first if the rows matter. No foreign keys
-- in either direction, so the drop cannot cascade.
DROP TABLE IF EXISTS "platform_bank_offers";
