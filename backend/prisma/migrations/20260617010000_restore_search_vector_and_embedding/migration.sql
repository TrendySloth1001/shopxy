-- ────────────────────────────────────────────────────────────────────
-- Restore the FTS + embedding columns silently dropped by the PDP
-- Phase B auto-generated migration (20260615000000) — that migration
-- was diffed against an outdated schema.prisma that didn't model the
-- raw-SQL columns from 20260530000000_search_fts_and_terms and
-- 20260601020000_embedding_dim_ollama_768, so Prisma generated DROP
-- statements for them without warning.
--
-- Until both columns are back, every POST /search returns 500
-- ("column p.search_vector does not exist") and the embedding sweeper
-- has nowhere to write. This migration re-creates them with the
-- original generated-column expression + GIN index for FTS and the
-- pgvector(768) column + ivfflat index for semantic search.
--
-- Guarded with IF NOT EXISTS so re-runs on a partially-recovered
-- shadow DB are no-ops.
-- ────────────────────────────────────────────────────────────────────

-- 1. Re-add the generated tsvector column. Same expression as the
--    original 20260530000000_search_fts_and_terms migration.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'products' AND column_name = 'search_vector'
  ) THEN
    ALTER TABLE "products"
      ADD COLUMN "search_vector" tsvector
      GENERATED ALWAYS AS (
        to_tsvector(
          'english',
          coalesce(name, '') || ' ' || coalesce(description, '')
        )
      ) STORED;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS "products_search_vector_idx"
  ON "products" USING GIN ("search_vector");

-- 2. Re-add the pgvector embedding column at 768 dims (Ollama nomic-
--    embed-text). New rows start NULL; the embed sweeper repopulates
--    them on its next tick. Existing search queries fall back to FTS
--    for any row whose embedding IS NULL, so the catalogue stays
--    searchable through the backfill.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'products' AND column_name = 'embedding'
  ) THEN
    ALTER TABLE products ADD COLUMN embedding vector(768);
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS products_embedding_ivfflat
  ON products USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 50)
  WHERE embedding IS NOT NULL;

-- 3. Reset the embed watermark so the sweeper picks every active row
--    up again on its next run. Mirrors what 20260601020000 did.
UPDATE products SET embedded_at = NULL WHERE is_active = TRUE;
