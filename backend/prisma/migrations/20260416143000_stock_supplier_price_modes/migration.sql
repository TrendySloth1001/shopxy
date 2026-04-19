-- AlterTable
ALTER TABLE "stock_transactions"
ADD COLUMN "supplier_name" TEXT,
ADD COLUMN "purchase_price_mode" TEXT,
ADD COLUMN "purchase_price_before" DECIMAL(12,2),
ADD COLUMN "purchase_price_after" DECIMAL(12,2);
