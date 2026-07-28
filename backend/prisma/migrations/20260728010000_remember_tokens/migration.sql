-- Device-remember credentials for one-tap return sign-in.
--
-- The `RememberToken` model shipped in schema.prisma alongside the whole
-- feature — service, controller, routes, the Flutter picker and its keychain
-- store — but no migration was ever written for it, so the table never existed
-- in any database. `prisma migrate dev` can't diff this schema (the
-- products.search_vector generated column makes it want a reset), which is why
-- migrations here are hand-written, and why this one was missed.
--
-- The symptom was silent by construction: POST /auth/remember hit a missing
-- relation and 500'd, `_rememberThisDevice()` swallows failures on purpose so
-- remembering can never block a sign-in, and the login picker renders
-- SizedBox.shrink() on an empty list. So "Continue as…" simply never appeared
-- and nothing anywhere said why.
--
-- Hand-written and applied with `prisma migrate resolve --applied`, matching
-- the HSN migrations.
CREATE TABLE "remember_tokens" (
  "id"           SERIAL       NOT NULL,
  -- SHA-256 hex of the opaque secret, never the raw token: the device keychain
  -- holds the only copy that can actually be replayed. Mirrors refresh_tokens.
  "token_hash"   TEXT         NOT NULL,
  "user_id"      INTEGER      NOT NULL,
  -- Free-text device/app label, for a future "trusted devices" list.
  "label"        TEXT,
  "expires_at"   TIMESTAMP(3) NOT NULL,
  "last_used_at" TIMESTAMP(3),
  "created_at"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "remember_tokens_pkey" PRIMARY KEY ("id")
);

-- Unique: the hash IS the lookup key on /auth/remember-login, and the
-- credential is single-use (rotated on every exchange).
CREATE UNIQUE INDEX "remember_tokens_token_hash_key"
  ON "remember_tokens"("token_hash");

-- Per-user listing, and the trim to MAX_REMEMBER_TOKENS_PER_USER on issue.
CREATE INDEX "remember_tokens_user_id_idx" ON "remember_tokens"("user_id");

-- Cascade: a deleted account must not leave behind a credential that still
-- exchanges for a session.
ALTER TABLE "remember_tokens"
  ADD CONSTRAINT "remember_tokens_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
