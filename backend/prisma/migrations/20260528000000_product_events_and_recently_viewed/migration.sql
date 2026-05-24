-- Phase 5 — Event ingestion.
--
-- Two new tables:
--   product_events    — raw activity stream (BIGINT id, JSON meta)
--   recently_viewed   — per-user materialised "last 20 viewed" list
--
-- Indexes mirror the three hot read patterns we expect:
--   * (product_id, event_type, occurred_at)  — per-product trending
--   * (user_id, occurred_at)                 — per-user activity timeline
--   * (occurred_at)                          — daily prune scan
--
-- client_uuid is unique so a retried POST is a no-op (createMany
-- skipDuplicates relies on the index existing).

CREATE TYPE "ProductEventType" AS ENUM (
    'IMPRESSION',
    'TAP',
    'VIEW',
    'ADD_TO_CART',
    'PURCHASE',
    'WISHLIST_ADD'
);

CREATE TABLE "product_events" (
    "id" BIGSERIAL PRIMARY KEY,
    "client_uuid" TEXT NOT NULL,
    "event_type" "ProductEventType" NOT NULL,
    "product_id" INTEGER NOT NULL,
    "user_id" INTEGER,
    "session_id" TEXT,
    "source" TEXT,
    "meta" JSONB,
    "occurred_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "product_events_product_id_fkey"
        FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE,
    CONSTRAINT "product_events_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL
);

CREATE UNIQUE INDEX "product_events_client_uuid_key"
    ON "product_events"("client_uuid");
CREATE INDEX "product_events_product_id_event_type_occurred_at_idx"
    ON "product_events"("product_id", "event_type", "occurred_at");
CREATE INDEX "product_events_user_id_occurred_at_idx"
    ON "product_events"("user_id", "occurred_at");
CREATE INDEX "product_events_occurred_at_idx"
    ON "product_events"("occurred_at");

CREATE TABLE "recently_viewed" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "last_viewed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "recently_viewed_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
    CONSTRAINT "recently_viewed_product_id_fkey"
        FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX "recently_viewed_user_id_product_id_key"
    ON "recently_viewed"("user_id", "product_id");
CREATE INDEX "recently_viewed_user_id_last_viewed_at_idx"
    ON "recently_viewed"("user_id", "last_viewed_at");
