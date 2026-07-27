-- HSN phase 3: record the product names the classifier could not place.
--
-- Hand-written and applied with `prisma migrate resolve --applied`, for the
-- same reason as the earlier HSN migrations: `prisma migrate dev` can't diff
-- this schema because of the products.search_vector generated column.
--
-- Retrieval is only as good as the vocabulary it searches, and the honest
-- source for what that vocabulary lacks is what merchants type and don't find.
-- Only misses are stored: a hit tells us nothing new, and writing on every
-- keystroke would cost the typing path a round trip for no information.
CREATE TABLE "hsn_lookup_misses" (
  "id"            SERIAL       NOT NULL,
  "shop_id"       INTEGER      NOT NULL,
  -- Normalised, so "Sarson ka Tel 1L" and "sarson ka tel 1l" are one gap.
  "term"          TEXT         NOT NULL,
  -- Verbatim, because the casing and punctuation the normaliser strips
  -- sometimes explain the miss.
  "sample"        TEXT         NOT NULL,
  "occurrences"   INTEGER      NOT NULL DEFAULT 1,
  "last_seen_at"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- Set when the gap is closed, so the backlog can tell "still missing" from
  -- "fixed, keeping the record".
  "resolved_code" TEXT,
  "resolved_at"   TIMESTAMP(3),
  "created_at"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "hsn_lookup_misses_pkey" PRIMARY KEY ("id")
);

-- The upsert key. A merchant retyping a name they can't place increments a
-- counter instead of flooding the table.
CREATE UNIQUE INDEX "hsn_lookup_misses_shop_id_term_key"
  ON "hsn_lookup_misses"("shop_id", "term");

-- The curation read: outstanding gaps, most-hit first.
CREATE INDEX "hsn_lookup_misses_resolved_code_occurrences_idx"
  ON "hsn_lookup_misses"("resolved_code", "occurrences");

-- Cascade: these are the shop's own product names and must not outlive it.
ALTER TABLE "hsn_lookup_misses"
  ADD CONSTRAINT "hsn_lookup_misses_shop_id_fkey"
  FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;
