-- CreateTable
CREATE TABLE "challans" (
    "id" SERIAL NOT NULL,
    "challan_no" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "party_name" TEXT NOT NULL,
    "party_phone" TEXT,
    "note" TEXT,
    "invoice_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "challans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "challan_items" (
    "id" SERIAL NOT NULL,
    "challan_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "product_name" TEXT NOT NULL,
    "product_sku" TEXT NOT NULL,
    "unit" TEXT NOT NULL DEFAULT 'PCS',
    "quantity" DECIMAL(12,3) NOT NULL,

    CONSTRAINT "challan_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "challans_challan_no_key" ON "challans"("challan_no");

-- CreateIndex
CREATE UNIQUE INDEX "challans_invoice_id_key" ON "challans"("invoice_id");

-- CreateIndex
CREATE INDEX "challans_status_idx" ON "challans"("status");

-- CreateIndex
CREATE INDEX "challans_created_at_idx" ON "challans"("created_at");

-- CreateIndex
CREATE INDEX "challan_items_challan_id_idx" ON "challan_items"("challan_id");

-- AddForeignKey
ALTER TABLE "challans" ADD CONSTRAINT "challans_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "invoices"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "challan_items" ADD CONSTRAINT "challan_items_challan_id_fkey" FOREIGN KEY ("challan_id") REFERENCES "challans"("id") ON DELETE CASCADE ON UPDATE CASCADE;
