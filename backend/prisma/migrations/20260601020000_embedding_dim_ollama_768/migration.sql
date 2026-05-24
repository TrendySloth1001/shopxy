-- ─────────────────────────────────────────────────────────────────────
-- Embedding provider swap: OpenAI text-embedding-3-small (1536) →
-- Ollama nomic-embed-text (768). pgvector columns are dimension-typed,
-- so the swap is a schema change: drop the dependent index, drop the
-- column, recreate at the new dim, clear the watermark so every active
-- row gets re-embedded by the next cron tick, then rebuild the index.
-- The catalogue stays searchable throughout — the search service
-- transparently falls back to FTS for rows whose embedding is NULL.

DROP INDEX IF EXISTS products_embedding_ivfflat;

ALTER TABLE products DROP COLUMN IF EXISTS embedding;
ALTER TABLE products ADD COLUMN embedding vector(768);

-- Reset the watermark so the embed-pending sweeper picks every active
-- row up again. Inactive rows stay NULL too — they're filtered out of
-- the sweeper's WHERE clause anyway.
UPDATE products SET embedded_at = NULL;

CREATE INDEX IF NOT EXISTS products_embedding_ivfflat
  ON products USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 50)
  WHERE embedding IS NOT NULL;
