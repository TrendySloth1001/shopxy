-- Seller-controlled customer-cancellation cut-off. Stages map to the
-- PurchaseRequestEvent milestones (PACKED / SHIPPED / OUT_FOR_DELIVERY /
-- DELIVERED). Default mirrors the common marketplace rule: cancellable
-- until the parcel ships.
ALTER TABLE "shops" ADD COLUMN "cancellation_policy" TEXT NOT NULL DEFAULT 'UNTIL_SHIPPED';
