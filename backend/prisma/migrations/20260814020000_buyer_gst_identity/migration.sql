-- Buyer-side GST identity, so a customer can claim input tax credit on a
-- marketplace purchase. Additive and nullable throughout: every existing user
-- and order stays exactly as it is (NULL = B2C, no ITC), so this is safe to
-- apply ahead of the code that writes it.

-- The customer's own registration. Separate from users.shop_gstin, which is
-- the merchant registration for the shop they own.
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "buyer_gstin" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "buyer_legal_name" TEXT;

-- Snapshots taken when the order is placed. Deliberately copied rather than
-- joined: editing the profile afterwards must not rewrite the recipient
-- identity an already-issued tax invoice was raised against.
ALTER TABLE "customer_orders" ADD COLUMN IF NOT EXISTS "buyer_gstin" TEXT;
ALTER TABLE "customer_orders" ADD COLUMN IF NOT EXISTS "buyer_legal_name" TEXT;

ALTER TABLE "purchase_requests" ADD COLUMN IF NOT EXISTS "buyer_gstin" TEXT;
ALTER TABLE "purchase_requests" ADD COLUMN IF NOT EXISTS "buyer_legal_name" TEXT;
