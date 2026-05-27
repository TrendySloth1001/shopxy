-- AlterTable
ALTER TABLE "shops" ADD COLUMN "vacation_mode"    BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "shops" ADD COLUMN "vacation_message" TEXT;
ALTER TABLE "shops" ADD COLUMN "operating_hours"  JSONB;
