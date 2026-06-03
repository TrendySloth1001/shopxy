-- Per-employee custom permissions. Each member carries an explicit set of
-- "<area>:<action>" rights (view/manage); the ShopRole is now just the preset
-- the owner started from. TEAM invites carry the granted set too, so an
-- employee's access can be hand-picked at invite time.
--
-- Backfill maps each existing staff member's role to its preset rights so
-- behaviour is unchanged on deploy. Owners keep an empty set (their role
-- bypasses every check in requireArea).

-- AlterTable
ALTER TABLE "shop_members" ADD COLUMN "permissions" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

-- AlterTable
ALTER TABLE "invitations" ADD COLUMN "team_permissions" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

-- Backfill preset rights for existing staff (owners stay empty → bypass).
UPDATE "shop_members" SET "permissions" = ARRAY[
  'products:view','products:manage',
  'orders:view','orders:manage',
  'invoices:view','invoices:manage',
  'payments:view','payments:manage',
  'parties:view','parties:manage',
  'stock:view','stock:manage',
  'vendors:view','vendors:manage',
  'marketing:view','marketing:manage',
  'shop:view','shop:manage',
  'reports:view'
] WHERE "role" = 'MANAGER';

UPDATE "shop_members" SET "permissions" = ARRAY[
  'stock:view','stock:manage',
  'vendors:view','vendors:manage',
  'products:view',
  'orders:view',
  'reports:view'
] WHERE "role" = 'STOCKIST';

UPDATE "shop_members" SET "permissions" = ARRAY[
  'invoices:view','invoices:manage',
  'payments:view','payments:manage',
  'parties:view','parties:manage',
  'products:view',
  'orders:view',
  'reports:view'
] WHERE "role" = 'CASHIER';
