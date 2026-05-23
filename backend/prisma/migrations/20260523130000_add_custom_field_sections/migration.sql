-- AlterTable
ALTER TABLE "custom_field_definitions" ADD COLUMN     "icon" TEXT,
ADD COLUMN     "section_id" INTEGER;

-- CreateTable
CREATE TABLE "custom_field_sections" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "icon" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "custom_field_sections_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "custom_field_sections_name_key" ON "custom_field_sections"("name");

-- CreateIndex
CREATE INDEX "custom_field_sections_is_active_idx" ON "custom_field_sections"("is_active");

-- CreateIndex
CREATE INDEX "custom_field_sections_sort_order_idx" ON "custom_field_sections"("sort_order");

-- CreateIndex
CREATE INDEX "custom_field_definitions_section_id_idx" ON "custom_field_definitions"("section_id");

-- AddForeignKey
ALTER TABLE "custom_field_definitions" ADD CONSTRAINT "custom_field_definitions_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "custom_field_sections"("id") ON DELETE SET NULL ON UPDATE CASCADE;

