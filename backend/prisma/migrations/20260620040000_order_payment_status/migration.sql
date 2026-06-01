-- Online-payment state for a customer order's gateway-payable remainder.
-- Additive: one nullable-with-default column; existing orders default to 'COD'
-- (cash on delivery), unchanged. Set to PAID by the ORDER gateway settlement.
ALTER TABLE "customer_orders" ADD COLUMN "payment_status" TEXT NOT NULL DEFAULT 'COD';
