-- Payment idempotency. Mobile clients on flaky networks retry POST
-- /payments without knowing whether the original succeeded — without
-- a key, every retry duplicates a row and silently over-pays the
-- invoice / inflates the party-vendor ledger.
--
-- The key is supplied by the client (`X-Idempotency-Key` header) and
-- scoped per (shop, type, key). A nullable column so unkeyed legacy
-- inserts continue to work; the partial unique only enforces
-- duplicates among keyed rows.

ALTER TABLE "payments"
  ADD COLUMN "idempotency_key" VARCHAR(120);

CREATE UNIQUE INDEX "payments_shop_id_type_idempotency_key_unique"
  ON "payments" ("shop_id", "type", "idempotency_key")
  WHERE "idempotency_key" IS NOT NULL;
