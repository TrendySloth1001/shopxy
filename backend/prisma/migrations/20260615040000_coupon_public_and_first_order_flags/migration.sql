-- Add `is_public` and `first_order_only` flags on coupons.
--
-- * Public coupons auto-apply at checkout when the cart matches their
--   constraints — surfaces in the customer's coupon carousel too.
-- * First-order-only restricts redemption to customers with zero prior
--   confirmed CustomerOrders, gated inside the redemption transaction.
ALTER TABLE "coupons"
  ADD COLUMN "is_public" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "first_order_only" BOOLEAN NOT NULL DEFAULT false;
