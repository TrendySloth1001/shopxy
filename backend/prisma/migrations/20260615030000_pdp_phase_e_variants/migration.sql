-- Phase E v1 — product variants. New ProductVariant table carrying
-- per-variant SKU/price/stock/images, Product.variantAxes for axis
-- definitions, Shop.variantsEnabled flag, and CartItem.variantId as
-- a nullable denorm of the customer's selection. Line-item tables
-- (InvoiceItem, StockTransaction, CostLayer, etc.) stay product-keyed
-- in v1; the ledger rewrite is Phase E v2.

-- AlterTable Product
ALTER TABLE "products" ADD COLUMN "variant_axes" JSONB;

-- AlterTable Shop
ALTER TABLE "shops" ADD COLUMN "variants_enabled" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable ProductVariant
CREATE TABLE "product_variants" (
    "id" SERIAL NOT NULL,
    "product_id" INTEGER NOT NULL,
    "sku" TEXT NOT NULL,
    "barcode" TEXT,
    "attributes" JSONB NOT NULL,
    "mrp" DECIMAL(12,2) NOT NULL,
    "selling_price" DECIMAL(12,2) NOT NULL,
    "purchase_price" DECIMAL(12,2) NOT NULL,
    "stock_quantity" DECIMAL(12,3) NOT NULL DEFAULT 0,
    "image_urls" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_variants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "product_variants_sku_key" ON "product_variants"("sku");
CREATE UNIQUE INDEX "product_variants_barcode_key" ON "product_variants"("barcode");
CREATE INDEX "product_variants_product_id_is_active_idx" ON "product_variants"("product_id", "is_active");
CREATE INDEX "product_variants_product_id_is_default_idx" ON "product_variants"("product_id", "is_default");

-- AddForeignKey
ALTER TABLE "product_variants" ADD CONSTRAINT "product_variants_product_id_fkey"
    FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AlterTable CartItem — add variantId + replace unique constraint
ALTER TABLE "cart_items" ADD COLUMN "variant_id" INTEGER;
DROP INDEX IF EXISTS "cart_items_user_id_product_id_key";
CREATE UNIQUE INDEX "cart_items_user_id_product_id_variant_id_key"
    ON "cart_items"("user_id", "product_id", "variant_id");
ALTER TABLE "cart_items" ADD CONSTRAINT "cart_items_variant_id_fkey"
    FOREIGN KEY ("variant_id") REFERENCES "product_variants"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
