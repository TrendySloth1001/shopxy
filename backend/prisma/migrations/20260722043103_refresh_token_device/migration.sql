-- Device context on sessions (for a "your devices" / revoke screen).
ALTER TABLE "refresh_tokens"
  ADD COLUMN IF NOT EXISTS "user_agent" TEXT,
  ADD COLUMN IF NOT EXISTS "ip_masked" TEXT,
  ADD COLUMN IF NOT EXISTS "last_used_at" TIMESTAMP(3);
