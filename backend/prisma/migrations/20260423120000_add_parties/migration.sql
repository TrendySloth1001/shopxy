-- CreateTable
CREATE TABLE "parties" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "contact_name" TEXT,
    "phone" TEXT,
    "email" TEXT,
    "address" TEXT,
    "gstin" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "parties_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "parties_name_idx" ON "parties"("name");

-- CreateIndex
CREATE INDEX "parties_is_active_idx" ON "parties"("is_active");

-- AlterTable
ALTER TABLE "challans" ADD COLUMN "party_id" INTEGER;

-- AlterTable
ALTER TABLE "invoices" ADD COLUMN "party_id" INTEGER;

-- CreateIndex
CREATE INDEX "challans_party_id_idx" ON "challans"("party_id");

-- CreateIndex
CREATE INDEX "invoices_party_id_idx" ON "invoices"("party_id");

-- AddForeignKey
ALTER TABLE "challans" ADD CONSTRAINT "challans_party_id_fkey" FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_party_id_fkey" FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE SET NULL ON UPDATE CASCADE;
