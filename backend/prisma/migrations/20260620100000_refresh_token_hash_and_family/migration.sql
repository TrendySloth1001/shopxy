-- B-AUTH-1 / B-AUTH-2: hashed refresh tokens + rotation-family reuse detection.
-- The `token` column now stores the SHA-256 hex of the issued JWT (not the raw
-- token). Existing rows hold raw JWTs that can no longer match a hashed lookup,
-- so we clear them — affected users simply sign in again.
DELETE FROM "refresh_tokens";

ALTER TABLE "refresh_tokens" ADD COLUMN "family" TEXT NOT NULL DEFAULT '';

CREATE INDEX "refresh_tokens_family_idx" ON "refresh_tokens"("family");
