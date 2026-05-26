-- Phase 2 / order tracking — append-only event log for the customer
-- order timeline. Lifecycle transitions (CREATED / CONFIRMED / REJECTED
-- / CANCELLED) are emitted by the purchase-requests service whenever
-- it changes a child's status; shipping events (PACKED / SHIPPED /
-- OUT_FOR_DELIVERY / DELIVERED / RETURNED) are recorded by the merchant
-- via POST /orders/:id/events.

CREATE TYPE "PurchaseRequestEventType" AS ENUM (
  'CREATED',
  'CONFIRMED',
  'REJECTED',
  'CANCELLED',
  'PACKED',
  'SHIPPED',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
  'RETURNED'
);

CREATE TABLE "purchase_request_events" (
  "id"          SERIAL PRIMARY KEY,
  "request_id"  INTEGER NOT NULL,
  "type"        "PurchaseRequestEventType" NOT NULL,
  "courier"     TEXT,
  "awb"         TEXT,
  "eta"         TIMESTAMP(3),
  "note"        TEXT,
  "actor_id"    INTEGER,
  "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "purchase_request_events_request_fkey"
    FOREIGN KEY ("request_id") REFERENCES "purchase_requests"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "purchase_request_events_actor_fkey"
    FOREIGN KEY ("actor_id") REFERENCES "users"("id")
    ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "purchase_request_events_request_occurred_idx"
  ON "purchase_request_events" ("request_id", "occurred_at");

-- Backfill: emit a CREATED event for every existing PurchaseRequest at
-- its createdAt. Same for CONFIRMED / REJECTED / CANCELLED using
-- decided_at when set. Lets the customer timeline render immediately
-- for legacy orders.

INSERT INTO "purchase_request_events"
  ("request_id", "type", "occurred_at")
SELECT id, 'CREATED', "created_at"
FROM "purchase_requests";

INSERT INTO "purchase_request_events"
  ("request_id", "type", "occurred_at", "actor_id")
SELECT id,
       CASE status
         WHEN 'CONFIRMED' THEN 'CONFIRMED'::"PurchaseRequestEventType"
         WHEN 'REJECTED'  THEN 'REJECTED'::"PurchaseRequestEventType"
         WHEN 'CANCELLED' THEN 'CANCELLED'::"PurchaseRequestEventType"
       END,
       COALESCE("decided_at", "updated_at"),
       "decided_by_id"
FROM "purchase_requests"
WHERE status IN ('CONFIRMED', 'REJECTED', 'CANCELLED');
