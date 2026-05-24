-- Phase 4 — Brand Spotlight + Editorial Collections.
--
-- Three new tables:
--   brand_spotlights — merchant-submitted, admin-approved promo placements
--   collections      — admin-curated editorial product lists, slug-keyed
--   collection_items — ordered membership rows for the above (M:N)
--
-- Conservative FKs:
--   brand_spotlights.shop_id        → shops.id            ON DELETE CASCADE
--   brand_spotlights.reviewed_by    → users.id            ON DELETE SET NULL
--   collection_items.collection_id  → collections.id      ON DELETE CASCADE
--   collection_items.product_id     → products.id         ON DELETE CASCADE

-- Enum for the moderation lifecycle.
CREATE TYPE "BrandSpotlightStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

CREATE TABLE "brand_spotlights" (
    "id" SERIAL PRIMARY KEY,
    "shop_id" INTEGER NOT NULL,
    "deal_label" TEXT NOT NULL,
    "subtitle" TEXT,
    "hero_image_url" TEXT NOT NULL,
    "bg_color" TEXT NOT NULL,
    "accent_color" TEXT,
    "cta_target" TEXT,
    "start_at" TIMESTAMP(3) NOT NULL,
    "end_at" TIMESTAMP(3) NOT NULL,
    "status" "BrandSpotlightStatus" NOT NULL DEFAULT 'PENDING',
    "rejection_reason" TEXT,
    "reviewed_by_user_id" INTEGER,
    "reviewed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "brand_spotlights_shop_id_fkey"
        FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE,
    CONSTRAINT "brand_spotlights_reviewed_by_user_id_fkey"
        FOREIGN KEY ("reviewed_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL,
    CONSTRAINT "brand_spotlights_end_after_start_chk"
        CHECK ("end_at" > "start_at")
);

CREATE INDEX "brand_spotlights_status_start_at_end_at_idx"
    ON "brand_spotlights"("status", "start_at", "end_at");
CREATE INDEX "brand_spotlights_shop_id_status_idx"
    ON "brand_spotlights"("shop_id", "status");

-- Editorial product lists. Slug is the public-facing key; uniqueness is
-- enforced by index so the auto-suffix path (`-2`, `-3`) can race-check
-- against actual conflict rather than scanning.
CREATE TABLE "collections" (
    "id" SERIAL PRIMARY KEY,
    "slug" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "eyebrow" TEXT,
    "subtitle" TEXT,
    "cta_text" TEXT,
    "cta_target" TEXT,
    "cover_image_url" TEXT,
    "bg_color" TEXT,
    "is_published" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL
);

CREATE UNIQUE INDEX "collections_slug_key" ON "collections"("slug");
CREATE INDEX "collections_is_published_sort_order_idx"
    ON "collections"("is_published", "sort_order");

CREATE TABLE "collection_items" (
    "id" SERIAL PRIMARY KEY,
    "collection_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "collection_items_collection_id_fkey"
        FOREIGN KEY ("collection_id") REFERENCES "collections"("id") ON DELETE CASCADE,
    CONSTRAINT "collection_items_product_id_fkey"
        FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX "collection_items_collection_id_product_id_key"
    ON "collection_items"("collection_id", "product_id");
CREATE INDEX "collection_items_collection_id_position_idx"
    ON "collection_items"("collection_id", "position");
CREATE INDEX "collection_items_product_id_idx"
    ON "collection_items"("product_id");
