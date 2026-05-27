-- AlterTable
ALTER TABLE "users" ADD COLUMN "notify_orders"   BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "users" ADD COLUMN "notify_deals"    BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "users" ADD COLUMN "notify_account"  BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "users" ADD COLUMN "notify_messages" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "users" ADD COLUMN "push_enabled"    BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "users" ADD COLUMN "sms_enabled"     BOOLEAN NOT NULL DEFAULT false;
