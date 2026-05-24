-- Denormalised review aggregates live on the product row so feed reads
-- never touch product_reviews. Defaults make backfill a no-op when no
-- reviews exist yet (true at migration time).
ALTER TABLE "products"
  ADD COLUMN "rating_avg"   DECIMAL(3,2),
  ADD COLUMN "rating_count" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "tags"         TEXT[]  NOT NULL DEFAULT '{}',
  ADD COLUMN "total_sold"   INTEGER NOT NULL DEFAULT 0;

-- One-shot backfill: derive total_sold from confirmed invoice lines.
-- Quantity is decimal (12,3) — products tracked in fractional units
-- (KG, LTR, …) round to nearest integer for the lifetime count, which
-- is acceptable for the sort-by-sales use case. PIECE-unit products
-- (the marketplace's hot path) are exact.
UPDATE "products" p
   SET "total_sold" = COALESCE(sums."qty", 0)::INTEGER
  FROM (
    SELECT ii.product_id, ROUND(SUM(ii.quantity))::INTEGER AS qty
      FROM "invoice_items" ii
      JOIN "invoices" i ON i.id = ii.invoice_id
     WHERE i.status = 'CONFIRMED'
     GROUP BY ii.product_id
  ) sums
 WHERE sums.product_id = p.id;

-- ProductReview table — one row per (product, user). The unique index
-- doubles as the upsert key when a user edits their review.
CREATE TABLE "product_reviews" (
    "id"         SERIAL NOT NULL,
    "product_id" INTEGER NOT NULL,
    "user_id"    INTEGER NOT NULL,
    "rating"     INTEGER NOT NULL,
    "title"      TEXT,
    "body"       TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_reviews_pkey" PRIMARY KEY ("id"),
    -- DB-level guard so a buggy service path can't write a 0 or 7. The
    -- service does its own zod validation; this is defence-in-depth.
    CONSTRAINT "product_reviews_rating_range" CHECK ("rating" >= 1 AND "rating" <= 5)
);

CREATE UNIQUE INDEX "product_reviews_product_id_user_id_key"
  ON "product_reviews"("product_id", "user_id");

-- Listing on a PDP fetches most-recent-first; covering index pays for
-- itself the first time the product has > a few dozen reviews.
CREATE INDEX "product_reviews_product_id_created_at_idx"
  ON "product_reviews"("product_id", "created_at" DESC);

ALTER TABLE "product_reviews"
  ADD CONSTRAINT "product_reviews_product_id_fkey"
  FOREIGN KEY ("product_id") REFERENCES "products"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "product_reviews"
  ADD CONSTRAINT "product_reviews_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
