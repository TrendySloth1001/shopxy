-- Teams & roles. Introduces shop-level staff membership so a shop can be
-- operated by more than just its owner, with coarse role-based permission
-- gating (see modules/team + shared/http/requirePermission).
--
-- Backfill is the load-bearing step: every existing shop owner is seeded as
-- a ShopMember(OWNER) so the moment shopId/shopRole resolution switches over
-- to shop_members (in signAccess / requireAuth / loadShopMiddleware), every
-- current owner keeps full access without re-login.

-- CreateEnum
CREATE TYPE "ShopRole" AS ENUM ('OWNER', 'MANAGER', 'STOCKIST', 'CASHIER');

-- CreateTable
CREATE TABLE "shop_members" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "user_id" INTEGER NOT NULL,
    "role" "ShopRole" NOT NULL DEFAULT 'CASHIER',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "shop_members_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "shop_members_user_id_key" ON "shop_members"("user_id");

-- CreateIndex
CREATE INDEX "shop_members_shop_id_idx" ON "shop_members"("shop_id");

-- CreateIndex
CREATE UNIQUE INDEX "shop_members_shop_id_user_id_key" ON "shop_members"("shop_id", "user_id");

-- AddForeignKey
ALTER TABLE "shop_members" ADD CONSTRAINT "shop_members_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shop_members" ADD CONSTRAINT "shop_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AlterTable: TEAM invites carry the ShopRole granted on accept.
ALTER TABLE "invitations" ADD COLUMN "team_role" "ShopRole";

-- Backfill: seed every existing shop's owner as an OWNER member. Idempotent
-- via the (shop_id, user_id) unique index, so a re-run is a no-op.
INSERT INTO "shop_members" ("shop_id", "user_id", "role", "created_at", "updated_at")
SELECT "id", "owner_user_id", 'OWNER', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "shops"
ON CONFLICT ("shop_id", "user_id") DO NOTHING;
