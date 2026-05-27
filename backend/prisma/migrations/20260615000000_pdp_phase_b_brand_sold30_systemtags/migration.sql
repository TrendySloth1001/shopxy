/*
  Warnings:

  - You are about to drop the column `embedding` on the `products` table. All the data in the column will be lost.
  - You are about to drop the column `search_vector` on the `products` table. All the data in the column will be lost.

*/
-- DropForeignKey
ALTER TABLE "brand_spotlights" DROP CONSTRAINT "brand_spotlights_reviewed_by_user_id_fkey";

-- DropForeignKey
ALTER TABLE "brand_spotlights" DROP CONSTRAINT "brand_spotlights_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "challans" DROP CONSTRAINT "challans_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "collection_items" DROP CONSTRAINT "collection_items_collection_id_fkey";

-- DropForeignKey
ALTER TABLE "collection_items" DROP CONSTRAINT "collection_items_product_id_fkey";

-- DropForeignKey
ALTER TABLE "counters" DROP CONSTRAINT "counters_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "custom_field_definitions" DROP CONSTRAINT "custom_field_definitions_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "custom_field_sections" DROP CONSTRAINT "custom_field_sections_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "customer_orders" DROP CONSTRAINT "customer_orders_customer_user_fk";

-- DropForeignKey
ALTER TABLE "flash_sales" DROP CONSTRAINT "flash_sales_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "invitations" DROP CONSTRAINT "invitations_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "invoices" DROP CONSTRAINT "invoices_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "parties" DROP CONSTRAINT "parties_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "payments" DROP CONSTRAINT "payments_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "product_events" DROP CONSTRAINT "product_events_product_id_fkey";

-- DropForeignKey
ALTER TABLE "product_events" DROP CONSTRAINT "product_events_user_id_fkey";

-- DropForeignKey
ALTER TABLE "promotions" DROP CONSTRAINT "promotions_product_id_fkey";

-- DropForeignKey
ALTER TABLE "promotions" DROP CONSTRAINT "promotions_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "purchase_request_items" DROP CONSTRAINT "purchase_request_items_product_fk";

-- DropForeignKey
ALTER TABLE "purchase_request_items" DROP CONSTRAINT "purchase_request_items_request_fk";

-- DropForeignKey
ALTER TABLE "purchase_requests" DROP CONSTRAINT "purchase_requests_customer_order_fk";

-- DropForeignKey
ALTER TABLE "purchase_requests" DROP CONSTRAINT "purchase_requests_customer_user_fk";

-- DropForeignKey
ALTER TABLE "purchase_requests" DROP CONSTRAINT "purchase_requests_decided_by_fk";

-- DropForeignKey
ALTER TABLE "purchase_requests" DROP CONSTRAINT "purchase_requests_invoice_fk";

-- DropForeignKey
ALTER TABLE "purchase_requests" DROP CONSTRAINT "purchase_requests_party_fk";

-- DropForeignKey
ALTER TABLE "purchase_requests" DROP CONSTRAINT "purchase_requests_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "recently_viewed" DROP CONSTRAINT "recently_viewed_product_id_fkey";

-- DropForeignKey
ALTER TABLE "recently_viewed" DROP CONSTRAINT "recently_viewed_user_id_fkey";

-- DropForeignKey
ALTER TABLE "recommendation_cache" DROP CONSTRAINT "recommendation_cache_user_id_fkey";

-- DropForeignKey
ALTER TABLE "search_events" DROP CONSTRAINT "search_events_user_id_fkey";

-- DropForeignKey
ALTER TABLE "stock_adjustments" DROP CONSTRAINT "stock_adjustments_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "stock_transactions" DROP CONSTRAINT "stock_transactions_shop_id_fkey";

-- DropForeignKey
ALTER TABLE "trending_scores" DROP CONSTRAINT "trending_scores_category_id_fkey";

-- DropForeignKey
ALTER TABLE "trending_scores" DROP CONSTRAINT "trending_scores_product_id_fkey";

-- DropForeignKey
ALTER TABLE "user_addresses" DROP CONSTRAINT "user_addresses_user_id_fkey";

-- DropForeignKey
ALTER TABLE "vendors" DROP CONSTRAINT "vendors_shop_id_fkey";

-- DropIndex
DROP INDEX "invitations_from_user_id_status_created_at_idx";

-- DropIndex
DROP INDEX "invitations_to_user_id_status_created_at_idx";

-- DropIndex
DROP INDEX "invoices_invoice_no_trgm";

-- DropIndex
DROP INDEX "notifications_user_id_created_at_idx";

-- DropIndex
DROP INDEX "parties_name_trgm";

-- DropIndex
DROP INDEX "products_barcode_trgm";

-- DropIndex
DROP INDEX "products_name_trgm";

-- DropIndex
DROP INDEX "products_search_vector_idx";

-- DropIndex
DROP INDEX "products_sku_trgm";

-- DropIndex
DROP INDEX "user_addresses_user_idx";

-- DropIndex
DROP INDEX "vendors_name_trgm";

-- AlterTable
ALTER TABLE "coupons" ALTER COLUMN "updated_at" DROP DEFAULT;

-- AlterTable
ALTER TABLE "customer_orders" ALTER COLUMN "updated_at" DROP DEFAULT;

-- AlterTable
ALTER TABLE "payments" ALTER COLUMN "idempotency_key" SET DATA TYPE TEXT;

-- AlterTable
ALTER TABLE "products" DROP COLUMN "embedding",
DROP COLUMN "search_vector",
ADD COLUMN     "brand" TEXT,
ADD COLUMN     "sold_last_30d" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "system_tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
ALTER COLUMN "embedded_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "recommendation_cache" ALTER COLUMN "product_ids" DROP DEFAULT;

-- AlterTable
ALTER TABLE "return_requests" ALTER COLUMN "updated_at" DROP DEFAULT;

-- AlterTable
ALTER TABLE "user_addresses" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3),
ALTER COLUMN "updated_at" DROP DEFAULT,
ALTER COLUMN "updated_at" SET DATA TYPE TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "invitations_to_user_id_status_created_at_idx" ON "invitations"("to_user_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "invitations_from_user_id_status_created_at_idx" ON "invitations"("from_user_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "notifications_user_id_created_at_idx" ON "notifications"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "products_brand_idx" ON "products"("brand");

-- CreateIndex
CREATE INDEX "products_sold_last_30d_idx" ON "products"("sold_last_30d");

-- CreateIndex
CREATE INDEX "user_addresses_user_id_created_at_idx" ON "user_addresses"("user_id", "created_at");

-- RenameForeignKey
ALTER TABLE "coupon_redemptions" RENAME CONSTRAINT "coupon_redemptions_coupon_fkey" TO "coupon_redemptions_coupon_id_fkey";

-- RenameForeignKey
ALTER TABLE "coupon_redemptions" RENAME CONSTRAINT "coupon_redemptions_order_fkey" TO "coupon_redemptions_customer_order_id_fkey";

-- RenameForeignKey
ALTER TABLE "coupon_redemptions" RENAME CONSTRAINT "coupon_redemptions_user_fkey" TO "coupon_redemptions_user_id_fkey";

-- RenameForeignKey
ALTER TABLE "coupons" RENAME CONSTRAINT "coupons_shop_fkey" TO "coupons_shop_id_fkey";

-- RenameForeignKey
ALTER TABLE "purchase_request_events" RENAME CONSTRAINT "purchase_request_events_actor_fkey" TO "purchase_request_events_actor_id_fkey";

-- RenameForeignKey
ALTER TABLE "purchase_request_events" RENAME CONSTRAINT "purchase_request_events_request_fkey" TO "purchase_request_events_request_id_fkey";

-- RenameForeignKey
ALTER TABLE "return_request_events" RENAME CONSTRAINT "return_request_events_actor_fkey" TO "return_request_events_actor_id_fkey";

-- RenameForeignKey
ALTER TABLE "return_request_events" RENAME CONSTRAINT "return_request_events_return_fkey" TO "return_request_events_return_id_fkey";

-- RenameForeignKey
ALTER TABLE "return_request_items" RENAME CONSTRAINT "return_request_items_pri_fkey" TO "return_request_items_purchase_request_item_id_fkey";

-- RenameForeignKey
ALTER TABLE "return_request_items" RENAME CONSTRAINT "return_request_items_return_fkey" TO "return_request_items_return_id_fkey";

-- RenameForeignKey
ALTER TABLE "return_requests" RENAME CONSTRAINT "return_requests_customer_fkey" TO "return_requests_customer_user_id_fkey";

-- RenameForeignKey
ALTER TABLE "return_requests" RENAME CONSTRAINT "return_requests_request_fkey" TO "return_requests_request_id_fkey";

-- RenameForeignKey
ALTER TABLE "return_requests" RENAME CONSTRAINT "return_requests_shop_fkey" TO "return_requests_shop_id_fkey";

-- RenameForeignKey
ALTER TABLE "return_requests" RENAME CONSTRAINT "return_requests_wallet_entry_fkey" TO "return_requests_wallet_entry_id_fkey";

-- RenameForeignKey
ALTER TABLE "wallet_entries" RENAME CONSTRAINT "wallet_entries_user_fkey" TO "wallet_entries_user_id_fkey";

-- AddForeignKey
ALTER TABLE "user_addresses" ADD CONSTRAINT "user_addresses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "custom_field_sections" ADD CONSTRAINT "custom_field_sections_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "custom_field_definitions" ADD CONSTRAINT "custom_field_definitions_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_transactions" ADD CONSTRAINT "stock_transactions_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_adjustments" ADD CONSTRAINT "stock_adjustments_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendors" ADD CONSTRAINT "vendors_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parties" ADD CONSTRAINT "parties_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "challans" ADD CONSTRAINT "challans_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_orders" ADD CONSTRAINT "customer_orders_customer_user_id_fkey" FOREIGN KEY ("customer_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_requests" ADD CONSTRAINT "purchase_requests_customer_order_id_fkey" FOREIGN KEY ("customer_order_id") REFERENCES "customer_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_requests" ADD CONSTRAINT "purchase_requests_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_requests" ADD CONSTRAINT "purchase_requests_customer_user_id_fkey" FOREIGN KEY ("customer_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_requests" ADD CONSTRAINT "purchase_requests_party_id_fkey" FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_requests" ADD CONSTRAINT "purchase_requests_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "invoices"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_requests" ADD CONSTRAINT "purchase_requests_decided_by_id_fkey" FOREIGN KEY ("decided_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_request_items" ADD CONSTRAINT "purchase_request_items_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "purchase_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchase_request_items" ADD CONSTRAINT "purchase_request_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "counters" ADD CONSTRAINT "counters_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "flash_sales" ADD CONSTRAINT "flash_sales_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "brand_spotlights" ADD CONSTRAINT "brand_spotlights_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "brand_spotlights" ADD CONSTRAINT "brand_spotlights_reviewed_by_user_id_fkey" FOREIGN KEY ("reviewed_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collection_items" ADD CONSTRAINT "collection_items_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "collections"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collection_items" ADD CONSTRAINT "collection_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_events" ADD CONSTRAINT "product_events_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_events" ADD CONSTRAINT "product_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recently_viewed" ADD CONSTRAINT "recently_viewed_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recently_viewed" ADD CONSTRAINT "recently_viewed_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trending_scores" ADD CONSTRAINT "trending_scores_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trending_scores" ADD CONSTRAINT "trending_scores_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recommendation_cache" ADD CONSTRAINT "recommendation_cache_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "search_events" ADD CONSTRAINT "search_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promotions" ADD CONSTRAINT "promotions_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promotions" ADD CONSTRAINT "promotions_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- RenameIndex
ALTER INDEX "coupon_redemptions_coupon_idx" RENAME TO "coupon_redemptions_coupon_id_idx";

-- RenameIndex
ALTER INDEX "coupon_redemptions_user_idx" RENAME TO "coupon_redemptions_user_id_redeemed_at_idx";

-- RenameIndex
ALTER INDEX "coupons_active_validuntil_idx" RENAME TO "coupons_is_active_valid_until_idx";

-- RenameIndex
ALTER INDEX "coupons_shop_active_idx" RENAME TO "coupons_shop_id_is_active_idx";

-- RenameIndex
ALTER INDEX "customer_orders_user_idempotency_key" RENAME TO "customer_orders_customer_user_id_idempotency_key_key";

-- RenameIndex
ALTER INDEX "invoices_place_of_supply_idx" RENAME TO "invoices_place_of_supply_state_code_idx";

-- RenameIndex
ALTER INDEX "purchase_request_events_request_occurred_idx" RENAME TO "purchase_request_events_request_id_occurred_at_idx";

-- RenameIndex
ALTER INDEX "return_request_events_return_occurred_idx" RENAME TO "return_request_events_return_id_occurred_at_idx";

-- RenameIndex
ALTER INDEX "return_request_items_return_idx" RENAME TO "return_request_items_return_id_idx";

-- RenameIndex
ALTER INDEX "return_requests_customer_created_idx" RENAME TO "return_requests_customer_user_id_created_at_idx";

-- RenameIndex
ALTER INDEX "return_requests_request_idx" RENAME TO "return_requests_request_id_idx";

-- RenameIndex
ALTER INDEX "return_requests_shop_status_created_idx" RENAME TO "return_requests_shop_id_status_created_at_idx";

-- RenameIndex
ALTER INDEX "wallet_entries_user_created_idx" RENAME TO "wallet_entries_user_id_created_at_idx";

-- RenameIndex
ALTER INDEX "wallet_entries_user_idempotency" RENAME TO "wallet_entries_user_id_idempotency_key_key";
