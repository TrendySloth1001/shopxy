-- CreateTable
CREATE TABLE "platform_bank_offers" (
    "id" SERIAL NOT NULL,
    "bank" TEXT NOT NULL,
    "card_type" TEXT NOT NULL,
    "discount_type" TEXT NOT NULL,
    "discount_value" DECIMAL(12,2) NOT NULL,
    "max_discount" DECIMAL(12,2),
    "min_order_amount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "terms" TEXT,
    "valid_from" TIMESTAMP(3) NOT NULL,
    "valid_until" TIMESTAMP(3) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "platform_bank_offers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "platform_bank_offers_is_active_valid_from_valid_until_idx"
    ON "platform_bank_offers"("is_active", "valid_from", "valid_until");

-- CreateIndex
CREATE INDEX "platform_bank_offers_bank_idx" ON "platform_bank_offers"("bank");
