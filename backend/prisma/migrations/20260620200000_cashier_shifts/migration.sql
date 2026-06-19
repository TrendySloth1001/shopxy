-- Cashier control center: till shifts + cash-drawer movements.

CREATE TABLE "cashier_shifts" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "opened_by_id" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "opening_float" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "closing_counted" DECIMAL(12,2),
    "expected_cash" DECIMAL(12,2),
    "variance" DECIMAL(12,2),
    "closing_note" TEXT,
    "opened_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_at" TIMESTAMP(3),
    "closed_by_id" INTEGER,
    CONSTRAINT "cashier_shifts_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "cashier_shifts_shop_id_status_idx" ON "cashier_shifts"("shop_id", "status");
CREATE INDEX "cashier_shifts_opened_by_id_status_idx" ON "cashier_shifts"("opened_by_id", "status");

CREATE TABLE "cash_movements" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "shift_id" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "reason" TEXT,
    "created_by_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "cash_movements_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "cash_movements_shift_id_idx" ON "cash_movements"("shift_id");
ALTER TABLE "cash_movements" ADD CONSTRAINT "cash_movements_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "cashier_shifts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- A sale carries the cashier's shift so the Z-report can reconcile cash.
ALTER TABLE "sales" ADD COLUMN "shift_id" INTEGER;
CREATE INDEX "sales_shift_id_idx" ON "sales"("shift_id");
