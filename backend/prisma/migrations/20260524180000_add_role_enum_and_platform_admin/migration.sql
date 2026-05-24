-- CreateEnum
CREATE TYPE "Role" AS ENUM ('OWNER', 'CUSTOMER');

-- AlterTable: convert existing role TEXT column to Role enum in place.
-- The USING clause preserves all existing values; both 'OWNER' and
-- 'CUSTOMER' string values are valid enum members. Any unexpected value
-- would raise — but there shouldn't be any (see auth.service.ts).
ALTER TABLE "users"
  ALTER COLUMN "role" DROP DEFAULT,
  ALTER COLUMN "role" TYPE "Role" USING "role"::"Role",
  ALTER COLUMN "role" SET DEFAULT 'OWNER';

-- AddColumn: platform-admin flag, defaults off. Flip on per-user for
-- cross-shop privileges (banner/collection/taxonomy curation).
ALTER TABLE "users"
  ADD COLUMN "is_platform_admin" BOOLEAN NOT NULL DEFAULT false;
