-- CreateTable
CREATE TABLE "contact_change_log" (
    "id" SERIAL NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" INTEGER NOT NULL,
    "field" TEXT NOT NULL,
    "old_value" TEXT,
    "new_value" TEXT,
    "changed_by_id" INTEGER,
    "changed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "contact_change_log_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "contact_change_log_entity_type_entity_id_changed_at_idx" ON "contact_change_log"("entity_type", "entity_id", "changed_at");

-- AddForeignKey
ALTER TABLE "contact_change_log" ADD CONSTRAINT "contact_change_log_changed_by_id_fkey" FOREIGN KEY ("changed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
