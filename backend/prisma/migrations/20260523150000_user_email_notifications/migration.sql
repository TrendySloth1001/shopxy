-- Per-user email-notifications preference. Default ON to match historical
-- behaviour (frontend was treating it as on but never persisting).
ALTER TABLE "users" ADD COLUMN "email_notifications" BOOLEAN NOT NULL DEFAULT true;
