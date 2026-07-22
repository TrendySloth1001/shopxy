-- Recent sign-ins / new-device detection.
CREATE TABLE IF NOT EXISTS "login_events" (
  "id" SERIAL PRIMARY KEY,
  "user_id" INTEGER NOT NULL REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "fingerprint" TEXT NOT NULL,
  "ip_masked" TEXT,
  "user_agent" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "login_events_user_id_fingerprint_idx" ON "login_events"("user_id","fingerprint");
CREATE INDEX IF NOT EXISTS "login_events_user_id_created_at_idx" ON "login_events"("user_id","created_at");
