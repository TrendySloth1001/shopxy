-- ─────────────────────────────────────────────────────────────────────
-- Semantic search foundation
-- ─────────────────────────────────────────────────────────────────────
-- Enables pgvector and adds an `embedding` column on products. We use
-- text-embedding-3-small (1536 dims) — the cheapest OpenAI embedding
-- that still hits production-quality recall. The column is nullable
-- so the system boots without any embeddings populated: the search
-- service falls back to pure FTS until the embed-pending cron has
-- caught up. An IVFFlat index gives sub-linear cosine ANN search for
-- catalogues larger than a few thousand SKUs; it's cheap to maintain
-- because re-embeds only happen on product updates, not on every
-- read.

CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS embedding vector(1536);

-- Watermark column so the embed-pending cron can skip rows that were
-- embedded *after* the last description/name update. NULL means the
-- row has never been embedded.
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS embedded_at timestamptz;

-- Partial index — only embedded products participate in vector
-- search; an IVFFlat over a sparsely-embedded table degrades fast.
-- `lists` tuned for the small-catalogue case; bump when row count
-- crosses ~100k. Uses cosine since OpenAI embeddings are unit-norm.
CREATE INDEX IF NOT EXISTS products_embedding_ivfflat
  ON products USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 50)
  WHERE embedding IS NOT NULL;

-- Lookup index for the embed-pending sweeper: "newest unembedded
-- product first" is what we want to process, since fresh listings
-- get the most search traffic.
CREATE INDEX IF NOT EXISTS products_embedding_pending
  ON products (updated_at DESC)
  WHERE embedding IS NULL AND is_active = true;

-- ─────────────────────────────────────────────────────────────────────
-- User addresses
-- ─────────────────────────────────────────────────────────────────────
-- Customer-facing delivery addresses. Decoupled from the existing
-- B2B `parties.address` String field on purpose — that one is a
-- single freeform line scoped to a merchant's invited customer; this
-- is a structured, user-owned list that the marketplace checkout
-- can target. One row is flagged `is_default = true` per user; the
-- partial unique index enforces it at the DB so two concurrent
-- "set as default" calls can't both win.

CREATE TABLE IF NOT EXISTS user_addresses (
  id              SERIAL PRIMARY KEY,
  user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label           TEXT,
  full_name       TEXT NOT NULL,
  phone           TEXT NOT NULL,
  line1           TEXT NOT NULL,
  line2           TEXT,
  city            TEXT NOT NULL,
  state           TEXT NOT NULL,
  pincode         TEXT NOT NULL,
  landmark        TEXT,
  is_default      BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS user_addresses_user_idx
  ON user_addresses (user_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS user_addresses_one_default_per_user
  ON user_addresses (user_id)
  WHERE is_default = true;
