-- CreateTable
CREATE TABLE "fbt_cache" (
    "product_id" INTEGER NOT NULL,
    "related_ids" INTEGER[],
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fbt_cache_pkey" PRIMARY KEY ("product_id")
);

-- CreateIndex
CREATE INDEX "fbt_cache_computed_at_idx" ON "fbt_cache"("computed_at");

-- AddForeignKey
ALTER TABLE "fbt_cache" ADD CONSTRAINT "fbt_cache_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
