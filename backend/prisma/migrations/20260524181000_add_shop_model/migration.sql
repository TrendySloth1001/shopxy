-- CreateTable
CREATE TABLE "shops" (
    "id" SERIAL NOT NULL,
    "owner_user_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "tagline" TEXT,
    "logo_url" TEXT,
    "banner_url" TEXT,
    "is_published" BOOLEAN NOT NULL DEFAULT false,
    "rating" DECIMAL(3,2),
    "rating_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "shops_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "shops_owner_user_id_key" ON "shops"("owner_user_id");
CREATE UNIQUE INDEX "shops_slug_key" ON "shops"("slug");
CREATE INDEX "shops_is_published_idx" ON "shops"("is_published");

-- AddForeignKey
ALTER TABLE "shops" ADD CONSTRAINT "shops_owner_user_id_fkey"
  FOREIGN KEY ("owner_user_id") REFERENCES "users"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: one shop per existing OWNER user. Slug derived from existing
-- shop_name (preferred) or name, lowercased, non-alnum collapsed to '-',
-- and disambiguated with the user id suffix to guarantee uniqueness.
-- Marketplace publish defaults to false — owners opt in via the new
-- Shop Profile screen so we don't surface half-configured shops.
INSERT INTO "shops" ("owner_user_id", "name", "slug", "is_published", "updated_at")
SELECT
  u.id,
  COALESCE(NULLIF(u.shop_name, ''), u.name),
  lower(
    regexp_replace(
      regexp_replace(COALESCE(NULLIF(u.shop_name, ''), u.name), '[^a-zA-Z0-9]+', '-', 'g'),
      '(^-+|-+$)', '', 'g'
    )
  ) || '-' || u.id,
  false,
  CURRENT_TIMESTAMP
FROM "users" u
WHERE u.role = 'OWNER';
