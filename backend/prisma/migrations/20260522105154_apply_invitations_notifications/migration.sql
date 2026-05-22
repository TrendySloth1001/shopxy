-- DropIndex
DROP INDEX "invitations_from_user_id_status_created_at_idx";

-- DropIndex
DROP INDEX "invitations_to_user_id_status_created_at_idx";

-- DropIndex
DROP INDEX "notifications_user_id_created_at_idx";

-- CreateIndex
CREATE INDEX "invitations_to_user_id_status_created_at_idx" ON "invitations"("to_user_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "invitations_from_user_id_status_created_at_idx" ON "invitations"("from_user_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "notifications_user_id_created_at_idx" ON "notifications"("user_id", "created_at");
