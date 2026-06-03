-- Owner-defined roles: roles become per-shop data. Seeds the three classic
-- roles as editable `builtin` rows for every existing shop so the roles
-- surface is fully data-driven from day one.

-- CreateTable
CREATE TABLE "team_roles" (
    "id" SERIAL NOT NULL,
    "shop_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "permissions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "builtin" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "team_roles_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "team_roles_shop_id_idx" ON "team_roles"("shop_id");
CREATE UNIQUE INDEX "team_roles_shop_id_name_key" ON "team_roles"("shop_id", "name");

-- AddForeignKey
ALTER TABLE "team_roles" ADD CONSTRAINT "team_roles_shop_id_fkey" FOREIGN KEY ("shop_id") REFERENCES "shops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- New label columns
ALTER TABLE "shop_members" ADD COLUMN "role_name" TEXT;
ALTER TABLE "invitations" ADD COLUMN "team_role_name" TEXT;

-- Backfill role_name for existing staff from their legacy enum role.
UPDATE "shop_members" SET "role_name" = initcap(lower("role"::text))
  WHERE "role" <> 'OWNER';

-- Seed the three starter roles for every shop (editable builtins).
INSERT INTO "team_roles" ("shop_id","name","permissions","builtin","updated_at")
SELECT s."id", 'Manager', ARRAY[
  'dashboard:view',
  'products:view','products:manage','orders:view','orders:manage',
  'invoices:view','invoices:manage','payments:view','payments:manage',
  'parties:view','parties:manage','stock:view','stock:manage',
  'vendors:view','vendors:manage','marketing:view','marketing:manage',
  'shop:view','shop:manage','reports:view'
], true, CURRENT_TIMESTAMP
FROM "shops" s ON CONFLICT ("shop_id","name") DO NOTHING;

INSERT INTO "team_roles" ("shop_id","name","permissions","builtin","updated_at")
SELECT s."id", 'Stockist', ARRAY[
  'dashboard:view','stock:view','stock:manage','vendors:view','vendors:manage',
  'products:view','orders:view','reports:view'
], true, CURRENT_TIMESTAMP
FROM "shops" s ON CONFLICT ("shop_id","name") DO NOTHING;

INSERT INTO "team_roles" ("shop_id","name","permissions","builtin","updated_at")
SELECT s."id", 'Cashier', ARRAY[
  'dashboard:view','invoices:view','invoices:manage','payments:view','payments:manage',
  'parties:view','parties:manage','products:view','orders:view','reports:view'
], true, CURRENT_TIMESTAMP
FROM "shops" s ON CONFLICT ("shop_id","name") DO NOTHING;
