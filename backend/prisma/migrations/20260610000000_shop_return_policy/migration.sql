-- Shop-level return policy. Existing shops keep the platform default
-- (returns enabled, 7-day window, wallet refunds) so nothing breaks
-- for live merchants the moment this migration runs.
ALTER TABLE "shops"
  ADD COLUMN "returns_enabled"     BOOLEAN  NOT NULL DEFAULT TRUE,
  ADD COLUMN "return_window_days"  INTEGER  NOT NULL DEFAULT 7,
  ADD COLUMN "refund_mode"         TEXT     NOT NULL DEFAULT 'WALLET',
  ADD COLUMN "return_policy_note"  TEXT;
