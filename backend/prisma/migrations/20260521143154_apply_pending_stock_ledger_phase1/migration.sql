-- DropIndex
DROP INDEX "stock_transactions_product_id_idx";

-- AlterTable
ALTER TABLE "cost_consumptions" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "cost_layers" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3);

-- AlterTable
ALTER TABLE "stock_adjustments" ALTER COLUMN "created_at" SET DATA TYPE TIMESTAMP(3);
