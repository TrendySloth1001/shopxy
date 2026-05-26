-- Stamp recorded each time we want to invalidate all access tokens
-- issued before this moment for a given user. Bumped on:
--   * password change
--   * explicit logout-all
--
-- requireAuth rejects access tokens whose `iat < tokensValidFrom`,
-- closing the 15-minute window after password change during which a
-- stolen access token would otherwise still work.

ALTER TABLE "users"
  ADD COLUMN "tokens_valid_from" TIMESTAMP(3);

-- Backfill: leave NULL for existing users so we don't invalidate every
-- live session on deploy. The middleware treats NULL as "no floor".
