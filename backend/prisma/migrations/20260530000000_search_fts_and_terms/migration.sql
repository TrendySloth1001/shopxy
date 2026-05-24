-- Phase 8 — Search backend.
--
-- 1. Add a generated tsvector column on products, GIN-indexed, for
--    full-text search. We use a *generated* column (Postgres 12+) so
--    INSERT / UPDATE never needs to remember to populate it — the
--    expression always re-derives from name + description.
--
-- 2. SearchTerm + SearchEvent tables for analytics + the /search/hints
--    surface.

-- The expression is wrapped in to_tsvector('english', …) — English
-- stemming is good enough for the marketplace's mixed catalogue.
-- Coalesces description because the column is nullable.
ALTER TABLE "products"
  ADD COLUMN "search_vector" tsvector
  GENERATED ALWAYS AS (
    to_tsvector(
      'english',
      coalesce(name, '') || ' ' || coalesce(description, '')
    )
  ) STORED;

CREATE INDEX "products_search_vector_idx"
  ON "products" USING GIN ("search_vector");

CREATE TABLE "search_terms" (
    "id" SERIAL PRIMARY KEY,
    "term" TEXT NOT NULL,
    "query_count" INTEGER NOT NULL DEFAULT 0,
    "last_searched_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "search_terms_term_key" ON "search_terms"("term");
CREATE INDEX "search_terms_last_searched_at_idx"
  ON "search_terms"("last_searched_at");
CREATE INDEX "search_terms_query_count_idx"
  ON "search_terms"("query_count");

CREATE TABLE "search_events" (
    "id" SERIAL PRIMARY KEY,
    "user_id" INTEGER,
    "session_id" TEXT,
    "query" TEXT NOT NULL,
    "result_count" INTEGER NOT NULL,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "search_events_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL
);
CREATE INDEX "search_events_user_id_occurred_at_idx"
  ON "search_events"("user_id", "occurred_at");
CREATE INDEX "search_events_occurred_at_idx"
  ON "search_events"("occurred_at");
