ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "google_id" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "recovery_pin_hash" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "recovery_pin_set_at" TIMESTAMP(3);

CREATE UNIQUE INDEX IF NOT EXISTS "users_google_id_key" ON "users"("google_id");
