-- Adds a nullable per-user idempotency key on PurchaseRequest. Lets the
-- customer app retry a flaky POST /me/orders without creating duplicate
-- orders. NULLs are treated as distinct in Postgres unique indexes, so
-- legacy rows with NULL keys don't conflict and the column can stay
-- optional.

ALTER TABLE "purchase_requests" ADD COLUMN "idempotency_key" TEXT;

CREATE UNIQUE INDEX "purchase_requests_customer_user_id_idempotency_key_key"
  ON "purchase_requests" ("customer_user_id", "idempotency_key");
