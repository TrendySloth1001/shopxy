-- AlterTable
ALTER TABLE "shops" ADD COLUMN "is_verified" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "shops" ADD COLUMN "location_city" TEXT;
ALTER TABLE "shops" ADD COLUMN "location_state" TEXT;
ALTER TABLE "shops" ADD COLUMN "return_policy" TEXT;
ALTER TABLE "shops" ADD COLUMN "shipping_policy" TEXT;
ALTER TABLE "shops" ADD COLUMN "refund_policy" TEXT;
