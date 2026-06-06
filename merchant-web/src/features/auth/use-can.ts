"use client";

import { useAuth } from "./auth-context";
import { canManage, canView } from "./capabilities";
import type { Area } from "@/features/team/permissions";

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
