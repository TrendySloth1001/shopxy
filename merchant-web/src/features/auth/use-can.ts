"use client";

import { useAuth } from "./auth-context";
import { canManage, canView, isShopOwner } from "./capabilities";
import { normalizeRights, type Area } from "@/features/team/permissions";

export function useCanManage(area: Area): boolean {
  const { user } = useAuth();
  return canManage(user, area);
}

export function useCanView(area: Area): boolean {
  const { user } = useAuth();
  return canView(user, area);
}

export function useGrantCeiling(): Set<string> | null {
  const { user } = useAuth();
  if (isShopOwner(user)) return null;
  return new Set(normalizeRights(user?.shopPermissions ?? []));
}
