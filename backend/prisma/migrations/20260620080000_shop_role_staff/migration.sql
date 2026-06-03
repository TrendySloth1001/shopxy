-- Generic non-owner role value. New staff are stored as STAFF; their real
-- access lives in shop_members.permissions and their label in role_name.
-- (Must be its own migration: a new enum value can't be *used* in the same
-- transaction it's added in.)
ALTER TYPE "ShopRole" ADD VALUE IF NOT EXISTS 'STAFF';
