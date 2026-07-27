-- HSN/SAC → GST rate master (see model HsnCode in schema.prisma).
--
-- Two tiers in one table: shop_id IS NULL rows are the platform master
-- (seeded at boot from the checked-in manifest), shop_id NOT NULL rows are
-- a merchant's private additions/overrides which win on lookup.
--
-- Effective-dated: a slab change closes the old row (effective_to) and
-- inserts a new one, so an invoice raised under the old rate still
-- re-renders correctly.
--
-- Hand-written rather than generated: `prisma migrate dev` can't diff this
-- schema (the products.search_vector generated column trips it), so this is
-- applied then marked with `prisma migrate resolve --applied`.

-- CreateEnum
CREATE TYPE "HsnKind" AS ENUM ('GOODS', 'SERVICES');

-- CreateTable
CREATE TABLE "hsn_codes" (
    "id" SERIAL NOT NULL,
    "code" TEXT NOT NULL,
    "kind" "HsnKind" NOT NULL DEFAULT 'GOODS',
    "description" TEXT NOT NULL,
    "gst_rate" DECIMAL(5,2) NOT NULL,
    "cess_rate" DECIMAL(5,2) NOT NULL DEFAULT 0,
    "rate_note" TEXT,
    "effective_from" DATE NOT NULL,
    "effective_to" DATE,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "shop_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "hsn_codes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "hsn_codes_code_shop_id_effective_from_key" ON "hsn_codes"("code", "shop_id", "effective_from");

-- CreateIndex
-- Postgres treats NULLs as distinct in a unique index, so the composite
-- above does NOT de-dupe the platform tier (shop_id IS NULL). This partial
-- index does, and is what the seed's raw upsert conflict-targets.
CREATE UNIQUE INDEX "hsn_codes_platform_code_effective_from_key" ON "hsn_codes"("code", "effective_from") WHERE "shop_id" IS NULL;

-- CreateIndex
CREATE INDEX "hsn_codes_code_is_active_idx" ON "hsn_codes"("code", "is_active");

-- CreateIndex
CREATE INDEX "hsn_codes_shop_id_idx" ON "hsn_codes"("shop_id");

-- CreateIndex
-- Prefix search ("type 6205, see 620510/620520/…") needs text_pattern_ops;
-- the default collation-aware btree above can't serve LIKE 'x%'.
CREATE INDEX "hsn_codes_code_prefix_idx" ON "hsn_codes"("code" text_pattern_ops);

-- AddForeignKey
ALTER TABLE "hsn_codes" ADD CONSTRAINT "hsn_codes_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;
