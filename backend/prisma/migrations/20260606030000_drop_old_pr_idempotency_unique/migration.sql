-- Drop the legacy per-user idempotency unique on purchase_requests.
--
-- History: migration 20260524170000_purchase_request_idempotency created
-- UNIQUE (customer_user_id, idempotency_key) under the Prisma-default
-- name `purchase_requests_customer_user_id_idempotency_key_key`.
-- Migration 20260603100000_multi_tenant_shop_scoping tried to drop it
-- via `purchase_requests_user_idempotency_key` (a name it never had)
-- and added the new (customer_user_id, shop_id, idempotency_key) unique
-- alongside it. The old index was therefore left in place — so when a
-- customer's split-cart checkout fires N POSTs with the same idempotency
-- key but different shop_ids, posts 2..N collide on the legacy
-- (customer_user_id, idempotency_key) unique and 409.
--
-- This migration drops the index by its real name. The newer
-- (customer_user_id, shop_id, idempotency_key) unique stays and is now
-- the only one gating dedup.

ALTER TABLE "purchase_requests"
  DROP CONSTRAINT IF EXISTS "purchase_requests_customer_user_id_idempotency_key_key";
DROP INDEX IF EXISTS "purchase_requests_customer_user_id_idempotency_key_key";
