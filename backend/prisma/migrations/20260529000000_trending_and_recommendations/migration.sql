-- Phase 6 — Trending + Recommendations.
--
-- Two new tables:
--   trending_scores       — per-(category, product) freshness score
--                           recomputed every 15 min from product_events
--   recommendation_cache  — per-user content-based shortlist
--                           (rebuilt nightly + on-purchase)
--
-- categoryId NULL means the global ("All") bucket. The unique
-- constraint over (category_id, product_id, window_end) is what makes
-- the upsert on recompute deterministic — we always know which row to
-- overwrite for the current snapshot.

CREATE TABLE "trending_scores" (
    "id" SERIAL PRIMARY KEY,
    "category_id" INTEGER,
    "product_id" INTEGER NOT NULL,
    "score" DECIMAL(12, 4) NOT NULL,
    "window_end" TIMESTAMP(3) NOT NULL,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "trending_scores_category_id_fkey"
        FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE,
    CONSTRAINT "trending_scores_product_id_fkey"
        FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX "trending_scores_category_id_product_id_window_end_key"
    ON "trending_scores"("category_id", "product_id", "window_end");
CREATE INDEX "trending_scores_category_id_score_idx"
    ON "trending_scores"("category_id", "score");
CREATE INDEX "trending_scores_window_end_idx"
    ON "trending_scores"("window_end");

CREATE TABLE "recommendation_cache" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INTEGER NOT NULL,
    "slot" TEXT NOT NULL,
    "product_ids" INTEGER[] NOT NULL DEFAULT '{}',
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "recommendation_cache_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX "recommendation_cache_user_id_slot_key"
    ON "recommendation_cache"("user_id", "slot");
CREATE INDEX "recommendation_cache_user_id_slot_idx"
    ON "recommendation_cache"("user_id", "slot");
