-- POS UPI-QR (P5): an AWAITING_PAYMENT Sale points at the GatewayPayment intent
-- whose Razorpay QR is being shown. Loose Int column (no FK) to match how
-- GatewayPayment is referenced elsewhere in this schema. The `AWAITING_PAYMENT`
-- Sale.status is a plain string value, so it needs no schema/enum change.
ALTER TABLE "sales" ADD COLUMN "gateway_payment_id" INTEGER;
