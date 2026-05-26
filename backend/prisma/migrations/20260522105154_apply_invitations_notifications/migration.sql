-- Originally this migration ran DROP INDEX + CREATE INDEX statements
-- against the `invitations` and `notifications` tables, but the timestamp
-- (10:51) sorts BEFORE 20260522170000_invitations_notifications which is
-- the migration that actually creates those tables. That works fine on a
-- production DB where the indexes were applied out-of-order historically,
-- but Prisma's shadow-database replay walks migrations alphabetically and
-- hits CREATE INDEX on a not-yet-existing table.
--
-- Wrap each block in a DO/IF-EXISTS guard so the shadow replay treats
-- this as a no-op when the tables aren't there yet; the next migration
-- creates them with the desired index shape directly, so semantics are
-- preserved. On production DBs (where the tables exist), the body still
-- runs and recreates the indexes, which is idempotent.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'invitations' AND table_schema = current_schema()
  ) THEN
    DROP INDEX IF EXISTS "invitations_from_user_id_status_created_at_idx";
    DROP INDEX IF EXISTS "invitations_to_user_id_status_created_at_idx";
    CREATE INDEX "invitations_to_user_id_status_created_at_idx"
      ON "invitations"("to_user_id", "status", "created_at");
    CREATE INDEX "invitations_from_user_id_status_created_at_idx"
      ON "invitations"("from_user_id", "status", "created_at");
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'notifications' AND table_schema = current_schema()
  ) THEN
    DROP INDEX IF EXISTS "notifications_user_id_created_at_idx";
    CREATE INDEX "notifications_user_id_created_at_idx"
      ON "notifications"("user_id", "created_at");
  END IF;
END
$$;
