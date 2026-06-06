"use client";

import { useAuth } from "./auth-context";
import { canManage, canView, isShopOwner } from "./capabilities";
import { normalizeRights, type Area } from "@/features/team/permissions";

/** True if the signed-in user can make changes in this area (write). */
export function useCanManage(area: Area): boolean {
  const { user } = useAuth();
  return canManage(user, area);
}

/** True if the signed-in user can view this area. */
export function useCanView(area: Area): boolean {
  const { user } = useAuth();
  return canView(user, area);
}

/**
 * The rights the signed-in user may grant to others (their own, normalised).
 * `null` for the shop owner (no ceiling). Used to pre-disable un-grantable
 * rows in the team permission matrix — the backend rejects grants beyond own
 * rights (`CANNOT_GRANT_BEYOND_OWN_RIGHTS`).
 */
export function useGrantCeiling(): Set<string> | null {
  const { user } = useAuth();
  if (isShopOwner(user)) return null;
  return new Set(normalizeRights(user?.shopPermissions ?? []));
}
