-- CASH-2: single-use ledger for manager-override grants. Each authorize mints a
-- short-lived JWT carrying a random jti bound to one shop + saleId + op; the
-- first replay INSERTs the jti here and the unique constraint makes the burn
-- atomic, so a replayed/reused grant is rejected. A DB row (not Redis) so the
-- single-use guard does NOT degrade open on a cache outage. Idempotent guards
-- let it re-run safely.

CREATE TABLE IF NOT EXISTS "pos_override_grants" (
  "id" serial PRIMARY KEY,
  "jti" text NOT NULL,
  "shop_id" integer NOT NULL,
  "sale_id" integer NOT NULL,
  "op" text NOT NULL,
  "authorized_by_id" integer NOT NULL,
  "expires_at" timestamp(3) NOT NULL,
  "consumed_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS "pos_override_grants_jti_key" ON "pos_override_grants" ("jti");
CREATE INDEX IF NOT EXISTS "pos_override_grants_expires_at_idx" ON "pos_override_grants" ("expires_at");
