-- POS open-cart tables (see POS_DESIGN.md). Hand-written to avoid the
-- generated-column (search_vector) drift that `migrate dev` emits.

CREATE TABLE "sales" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "version" INTEGER NOT NULL DEFAULT 0,
    "party_id" INTEGER,
    "customer_name" TEXT,
    "customer_phone" TEXT,
    "header_discount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "note" TEXT,
    "invoice_id" INTEGER,
    "opened_by_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "sales_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "sale_lines" (
    "id" SERIAL NOT NULL,
    "sale_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "quantity" DECIMAL(12,3) NOT NULL,
    "unit_price" DECIMAL(12,2) NOT NULL,
    "line_discount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "added_by_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "sale_lines_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "sales_invoice_id_key" ON "sales"("invoice_id");
CREATE INDEX "sales_shop_id_status_idx" ON "sales"("shop_id", "status");
CREATE UNIQUE INDEX "sale_lines_sale_id_product_id_key" ON "sale_lines"("sale_id", "product_id");
CREATE INDEX "sale_lines_sale_id_idx" ON "sale_lines"("sale_id");

ALTER TABLE "sales" ADD CONSTRAINT "sales_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "sales" ADD CONSTRAINT "sales_party_id_fkey" FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "sales" ADD CONSTRAINT "sales_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "invoices"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "sale_lines" ADD CONSTRAINT "sale_lines_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "sale_lines" ADD CONSTRAINT "sale_lines_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
