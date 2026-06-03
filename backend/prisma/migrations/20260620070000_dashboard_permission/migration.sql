-- Split the dashboard into its own view-gated area (was lumped with reports).
-- Any existing staffer who could see reports also keeps dashboard access, so
-- behaviour is unchanged on deploy. Owners are unaffected (role bypass).
UPDATE "shop_members"
SET "permissions" = array_append("permissions", 'dashboard:view')
WHERE 'reports:view' = ANY("permissions")
  AND NOT ('dashboard:view' = ANY("permissions"));
