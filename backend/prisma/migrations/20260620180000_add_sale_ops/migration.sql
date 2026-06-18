-- POS op-id dedupe ledger (P3 resilient-online).
CREATE TABLE "sale_ops" (
    "id" SERIAL NOT NULL,
    "sale_id" INTEGER NOT NULL,
    "op_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "sale_ops_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "sale_ops_sale_id_op_id_key" ON "sale_ops"("sale_id", "op_id");
ALTER TABLE "sale_ops" ADD CONSTRAINT "sale_ops_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;
