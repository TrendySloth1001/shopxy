-- Two-factor auth (TOTP) columns on users.
ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "totp_secret" TEXT,
  ADD COLUMN IF NOT EXISTS "totp_enabled_at" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "totp_recovery_codes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
