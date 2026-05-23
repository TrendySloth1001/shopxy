
-- CreateTable
CREATE TABLE "custom_field_definitions" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "options" JSONB,
    "unit_suffix" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "custom_field_definitions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_custom_field_values" (
    "id" SERIAL NOT NULL,
    "product_id" INTEGER NOT NULL,
    "definition_id" INTEGER NOT NULL,
    "value" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_custom_field_values_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "custom_field_definitions_name_key" ON "custom_field_definitions"("name");

-- CreateIndex
CREATE INDEX "custom_field_definitions_is_active_idx" ON "custom_field_definitions"("is_active");

-- CreateIndex
CREATE INDEX "custom_field_definitions_sort_order_idx" ON "custom_field_definitions"("sort_order");

-- CreateIndex
CREATE INDEX "product_custom_field_values_definition_id_idx" ON "product_custom_field_values"("definition_id");

-- CreateIndex
CREATE UNIQUE INDEX "product_custom_field_values_product_id_definition_id_key" ON "product_custom_field_values"("product_id", "definition_id");

-- AddForeignKey
ALTER TABLE "product_custom_field_values" ADD CONSTRAINT "product_custom_field_values_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_custom_field_values" ADD CONSTRAINT "product_custom_field_values_definition_id_fkey" FOREIGN KEY ("definition_id") REFERENCES "custom_field_definitions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

