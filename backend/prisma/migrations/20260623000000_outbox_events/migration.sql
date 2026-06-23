-- Transactional outbox (event-driven backbone). Additive only — no changes to
-- existing tables. Idempotent (IF NOT EXISTS) so it is safe to (re)apply.
--
-- Domain writes insert a row here in the same transaction as the business
-- change; the relay (src/infra/outbox/relay.ts) drains PENDING rows with
-- FOR UPDATE SKIP LOCKED and fans them out to derived read models.

CREATE TABLE IF NOT EXISTS "outbox_events" (
  "id" BIGSERIAL NOT NULL,
  "aggregate_type" TEXT NOT NULL,
  "aggregate_id" TEXT NOT NULL,
  "event_type" TEXT NOT NULL,
  "shop_id" INTEGER,
  "payload" JSONB NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "last_error" TEXT,
  "available_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "claimed_at" TIMESTAMP(3),
  "published_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id")
);

-- Relay hot path: claim PENDING rows that are due now, oldest first.
CREATE INDEX IF NOT EXISTS "outbox_events_status_available_at_id_idx"
  ON "outbox_events" ("status", "available_at", "id");

-- Lookups by aggregate (debugging, replay of one aggregate's history).
CREATE INDEX IF NOT EXISTS "outbox_events_aggregate_type_aggregate_id_idx"
  ON "outbox_events" ("aggregate_type", "aggregate_id");
