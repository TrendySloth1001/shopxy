-- AlterTable
ALTER TABLE "parties" ADD COLUMN "linked_user_id" INTEGER;
ALTER TABLE "vendors" ADD COLUMN "linked_user_id" INTEGER;

-- AddForeignKey (set null on user delete so party/vendor history survives)
ALTER TABLE "parties"
    ADD CONSTRAINT "parties_linked_user_id_fkey"
    FOREIGN KEY ("linked_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "vendors"
    ADD CONSTRAINT "vendors_linked_user_id_fkey"
    FOREIGN KEY ("linked_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "parties_linked_user_id_idx" ON "parties"("linked_user_id");
CREATE INDEX "vendors_linked_user_id_idx" ON "vendors"("linked_user_id");

-- CreateTable: invitations
CREATE TABLE "invitations" (
    "id" SERIAL NOT NULL,
    "from_user_id" INTEGER NOT NULL,
    "to_email" TEXT NOT NULL,
    "to_user_id" INTEGER,
    "link_type" TEXT NOT NULL,
    "party_id" INTEGER,
    "vendor_id" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "message" TEXT,
    "from_shop_name" TEXT,
    "display_name" TEXT,
    "token" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "responded_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "invitations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "invitations_token_key" ON "invitations"("token");

-- Indexes serve the three hot paths described in the schema.
CREATE INDEX "invitations_to_email_status_idx" ON "invitations"("to_email", "status");
CREATE INDEX "invitations_to_user_id_status_created_at_idx"
    ON "invitations"("to_user_id", "status", "created_at" DESC);
CREATE INDEX "invitations_from_user_id_status_created_at_idx"
    ON "invitations"("from_user_id", "status", "created_at" DESC);
CREATE INDEX "invitations_status_expires_at_idx" ON "invitations"("status", "expires_at");

-- Partial unique index: stop the owner from creating multiple PENDING
-- invites for the same email + entity. NULLs deliberately allowed for
-- the party / vendor side that isn't in use.
CREATE UNIQUE INDEX "invitations_pending_party_uniq"
    ON "invitations"("from_user_id", "to_email", "party_id")
    WHERE "status" = 'PENDING' AND "party_id" IS NOT NULL;

CREATE UNIQUE INDEX "invitations_pending_vendor_uniq"
    ON "invitations"("from_user_id", "to_email", "vendor_id")
    WHERE "status" = 'PENDING' AND "vendor_id" IS NOT NULL;

-- AddForeignKey
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_from_user_id_fkey"
    FOREIGN KEY ("from_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_to_user_id_fkey"
    FOREIGN KEY ("to_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_party_id_fkey"
    FOREIGN KEY ("party_id") REFERENCES "parties"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "invitations" ADD CONSTRAINT "invitations_vendor_id_fkey"
    FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable: notifications
CREATE TABLE "notifications" (
    "id" SERIAL NOT NULL,
    "user_id" INTEGER NOT NULL,
    "kind" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT,
    "data" JSONB,
    "read_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- (userId, readAt) keeps unread-count an index-only scan; second index
-- supports the chronological inbox.
CREATE INDEX "notifications_user_id_read_at_idx" ON "notifications"("user_id", "read_at");
CREATE INDEX "notifications_user_id_created_at_idx" ON "notifications"("user_id", "created_at" DESC);

ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
