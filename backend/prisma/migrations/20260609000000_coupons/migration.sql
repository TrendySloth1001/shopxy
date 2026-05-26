-- Phase 4 — coupon ledger + customer order audit columns.

ALTER TABLE "customer_orders"
  ADD COLUMN "coupon_discount" DECIMAL(12, 2) NOT NULL DEFAULT 0,
  ADD COLUMN "wallet_paid"     DECIMAL(12, 2) NOT NULL DEFAULT 0;

CREATE TABLE "coupons" (
  "id"                 SERIAL PRIMARY KEY,
  "code"               TEXT NOT NULL UNIQUE,
  "title"              TEXT NOT NULL,
  "description"        TEXT,
  "discount_type"      TEXT NOT NULL,
  "discount_value"     DECIMAL(12, 2) NOT NULL,
  "max_discount"       DECIMAL(12, 2),
  "min_order_amount"   DECIMAL(12, 2) NOT NULL DEFAULT 0,
  "valid_from"         TIMESTAMP(3) NOT NULL,
  "valid_until"        TIMESTAMP(3) NOT NULL,
  "per_user_limit"     INTEGER NOT NULL DEFAULT 1,
  "total_cap"          INTEGER NOT NULL DEFAULT 0,
  "total_redemptions"  INTEGER NOT NULL DEFAULT 0,
  "shop_id"            INTEGER,
  "is_active"          BOOLEAN NOT NULL DEFAULT true,
  "created_at"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "coupons_shop_fkey"
    FOREIGN KEY ("shop_id") REFERENCES "shops"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "coupons_active_validuntil_idx" ON "coupons" ("is_active", "valid_until");
CREATE INDEX "coupons_shop_active_idx" ON "coupons" ("shop_id", "is_active");

CREATE TABLE "coupon_redemptions" (
  "id"                  SERIAL PRIMARY KEY,
  "coupon_id"           INTEGER NOT NULL,
  "user_id"             INTEGER NOT NULL,
  "customer_order_id"   INTEGER NOT NULL UNIQUE,
  "discount_amount"     DECIMAL(12, 2) NOT NULL,
  "redeemed_at"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "coupon_redemptions_coupon_fkey"
    FOREIGN KEY ("coupon_id") REFERENCES "coupons"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "coupon_redemptions_user_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "coupon_redemptions_order_fkey"
    FOREIGN KEY ("customer_order_id") REFERENCES "customer_orders"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "coupon_redemptions_user_idx"
  ON "coupon_redemptions" ("user_id", "redeemed_at");
CREATE INDEX "coupon_redemptions_coupon_idx"
  ON "coupon_redemptions" ("coupon_id");
