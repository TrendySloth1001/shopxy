/*
  Warnings:

  - You are about to drop the column `accent_color` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `bg_color` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `brand_image_fit` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `brand_image_url` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `brand_label` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `carousel_id` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `cta_target` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `cta_text` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `eyebrow` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `image_fit` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `sponsor_shop_id` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `subtitle` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `template` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the column `title` on the `banners` table. All the data in the column will be lost.
  - You are about to drop the `banner_products` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `brand_spotlights` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `carousels` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `collection_items` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `collections` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `flash_sales` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `promotions` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "banner_products" DROP CONSTRAINT "banner_products_banner_id_fkey";

-- DropForeignKey
ALTER TABLE "banner_products" DROP CONSTRAINT "banner_products_product_id_fkey";

-- DropForeignKey
ALTER TABLE "banners" DROP CONSTRAINT "banners_carousel_id_fkey";

-- DropForeignKey
ALTER TABLE "banners" DROP CONSTRAINT "banners_sponsor_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "brand_spotlights" DROP CONSTRAINT "brand_spotlights_reviewed_by_user_id_fkey";

-- DropForeignKey
ALTER TABLE "brand_spotlights" DROP CONSTRAINT "brand_spotlights_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "carousels" DROP CONSTRAINT "carousels_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "collection_items" DROP CONSTRAINT "collection_items_collection_id_fkey";

-- DropForeignKey
ALTER TABLE "collection_items" DROP CONSTRAINT "collection_items_product_id_fkey";

-- DropForeignKey
ALTER TABLE "flash_sales" DROP CONSTRAINT "flash_sales_product_id_fkey";

-- DropForeignKey
ALTER TABLE "flash_sales" DROP CONSTRAINT "flash_sales_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "promotions" DROP CONSTRAINT "promotions_product_id_fkey";

-- DropForeignKey
ALTER TABLE "promotions" DROP CONSTRAINT "promotions_shop_id_fkey";

-- DropIndex
DROP INDEX "banners_carousel_id_sort_order_idx";

-- DropIndex
DROP INDEX "banners_sponsor_shop_id_idx";

-- AlterTable
ALTER TABLE "banners" DROP COLUMN "accent_color",
DROP COLUMN "bg_color",
DROP COLUMN "brand_image_fit",
DROP COLUMN "brand_image_url",
DROP COLUMN "brand_label",
DROP COLUMN "carousel_id",
DROP COLUMN "cta_target",
DROP COLUMN "cta_text",
DROP COLUMN "eyebrow",
DROP COLUMN "image_fit",
DROP COLUMN "sponsor_shop_id",
DROP COLUMN "subtitle",
DROP COLUMN "template",
DROP COLUMN "title",
ADD COLUMN     "link_url" TEXT,
ADD COLUMN     "shop_id" INTEGER;

-- AlterTable
ALTER TABLE "shop_members" ALTER COLUMN "role" SET DEFAULT 'STAFF';

-- DropTable
DROP TABLE "banner_products";

-- DropTable
DROP TABLE "brand_spotlights";

-- DropTable
DROP TABLE "carousels";

-- DropTable
DROP TABLE "collection_items";

-- DropTable
DROP TABLE "collections";

-- DropTable
DROP TABLE "flash_sales";

-- DropTable
DROP TABLE "promotions";

-- DropEnum
DROP TYPE "BannerImageFit";

-- DropEnum
DROP TYPE "BannerProductDiscountType";

-- DropEnum
DROP TYPE "BannerTemplate";

-- DropEnum
DROP TYPE "BrandSpotlightStatus";

-- CreateIndex
CREATE INDEX "banners_shop_id_idx" ON "banners"("shop_id");

-- AddForeignKey
ALTER TABLE "banners" ADD CONSTRAINT "banners_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE SET NULL ON UPDATE CASCADE;
