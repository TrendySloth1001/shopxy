-- Phase 3 — returns + wallet ledger.
--
-- ReturnRequest tracks a partial-or-full return against a single
-- PurchaseRequest (per-shop slice). Items reference the original
-- PurchaseRequestItem so the merchant inbox shows the right line.
-- WalletEntry is the append-only ledger that refunds (and Phase 4's
-- coupons + Phase 5's loyalty/referral) post into; User.wallet_balance
-- is the denormed sum kept in sync inside the same transaction.

ALTER TABLE "users"
  ADD COLUMN "wallet_balance" DECIMAL(12, 2) NOT NULL DEFAULT 0;

CREATE TABLE "wallet_entries" (
  "id"              SERIAL PRIMARY KEY,
  "user_id"         INTEGER NOT NULL,
  "amount"          DECIMAL(12, 2) NOT NULL,
  "balance_after"   DECIMAL(12, 2) NOT NULL,
  "source"          TEXT NOT NULL,
  "source_id"       INTEGER,
  "description"     TEXT NOT NULL,
  "idempotency_key" TEXT,
  "created_at"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "wallet_entries_user_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "wallet_entries_user_created_idx"
  ON "wallet_entries" ("user_id", "created_at");

-- Idempotency unique: NULL keys don't collide, so non-keyed entries
-- (manual top-ups, etc.) can repeat freely.
CREATE UNIQUE INDEX "wallet_entries_user_idempotency"
  ON "wallet_entries" ("user_id", "idempotency_key")
  WHERE "idempotency_key" IS NOT NULL;

CREATE TABLE "return_requests" (
  "id"               SERIAL PRIMARY KEY,
  "request_id"       INTEGER NOT NULL,
  "shop_id"          INTEGER NOT NULL,
  "customer_user_id" INTEGER NOT NULL,
  "status"           TEXT NOT NULL DEFAULT 'REQUESTED',
  "refund_amount"    DECIMAL(12, 2) NOT NULL DEFAULT 0,
  "refund_method"    TEXT,
  "note"             TEXT,
  "decision_note"    TEXT,
  "wallet_entry_id"  INTEGER UNIQUE,
  "created_at"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"       TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "return_requests_request_fkey"
    FOREIGN KEY ("request_id") REFERENCES "purchase_requests"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "return_requests_shop_fkey"
    FOREIGN KEY ("shop_id") REFERENCES "shops"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "return_requests_customer_fkey"
    FOREIGN KEY ("customer_user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "return_requests_wallet_entry_fkey"
    FOREIGN KEY ("wallet_entry_id") REFERENCES "wallet_entries"("id")
    ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "return_requests_customer_created_idx"
  ON "return_requests" ("customer_user_id", "created_at");
CREATE INDEX "return_requests_shop_status_created_idx"
  ON "return_requests" ("shop_id", "status", "created_at");
CREATE INDEX "return_requests_request_idx"
  ON "return_requests" ("request_id");

CREATE TABLE "return_request_items" (
  "id"                       SERIAL PRIMARY KEY,
  "return_id"                INTEGER NOT NULL,
  "purchase_request_item_id" INTEGER NOT NULL,
  "reason"                   TEXT NOT NULL,
  "quantity"                 DECIMAL(12, 3) NOT NULL,
  "refund_amount"            DECIMAL(12, 2) NOT NULL,

  CONSTRAINT "return_request_items_return_fkey"
    FOREIGN KEY ("return_id") REFERENCES "return_requests"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "return_request_items_pri_fkey"
    FOREIGN KEY ("purchase_request_item_id") REFERENCES "purchase_request_items"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "return_request_items_return_idx"
  ON "return_request_items" ("return_id");

CREATE TABLE "return_request_events" (
  "id"          SERIAL PRIMARY KEY,
  "return_id"   INTEGER NOT NULL,
  "type"        TEXT NOT NULL,
  "note"        TEXT,
  "actor_id"    INTEGER,
  "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "return_request_events_return_fkey"
    FOREIGN KEY ("return_id") REFERENCES "return_requests"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "return_request_events_actor_fkey"
    FOREIGN KEY ("actor_id") REFERENCES "users"("id")
    ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "return_request_events_return_occurred_idx"
  ON "return_request_events" ("return_id", "occurred_at");
