-- CreateEnum
CREATE TYPE "BannerProductDiscountType" AS ENUM ('PERCENT', 'AMOUNT');

-- CreateTable
CREATE TABLE "banner_products" (
    "id" SERIAL NOT NULL,
    "banner_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "discount_type" "BannerProductDiscountType" NOT NULL DEFAULT 'PERCENT',
    "discount_value" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "banner_products_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "banner_products_banner_id_position_idx" ON "banner_products"("banner_id", "position");

-- CreateIndex
CREATE INDEX "banner_products_product_id_idx" ON "banner_products"("product_id");

-- CreateIndex
CREATE UNIQUE INDEX "banner_products_banner_id_product_id_key" ON "banner_products"("banner_id", "product_id");

-- AddForeignKey
ALTER TABLE "banner_products" ADD CONSTRAINT "banner_products_banner_id_fkey" FOREIGN KEY ("banner_id") REFERENCES "banners"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "banner_products" ADD CONSTRAINT "banner_products_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
