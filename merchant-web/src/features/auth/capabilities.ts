/**
 * Shop capability helpers — the web mirror of the Flutter merchant app's
 * `lib/core/auth/shop_capabilities.dart`. The backend is the source of truth
 * (`requireArea` 403s); these gate the UI so people only see what they can use.
 *
 * Rules, identical to `backend/src/shared/http/permissions.ts#hasRight`:
 *   - `shopRole === "OWNER"` bypasses every check (full access).
 *   - otherwise a grant must exist in `shopPermissions` ("area:view"/"area:manage").
 *   - `:manage` implies `:view`.
 *   - no grant → denied (fail-closed).
 */
import type { AuthUser } from "./types";
import { type Area, hasRight, manageRight, viewRight } from "@/features/team/permissions";

export function isShopOwner(user: AuthUser | null | undefined): boolean {
  return user?.shopRole === "OWNER";
}

/** Can the user see this area at all? */
export function canView(user: AuthUser | null | undefined, area: Area): boolean {
  if (!user) return false;
  if (isShopOwner(user)) return true;
  return hasRight(user.shopPermissions ?? [], viewRight(area));
}

/** Can the user make changes in this area? */
export function canManage(user: AuthUser | null | undefined, area: Area): boolean {
  if (!user) return false;
  if (isShopOwner(user)) return true;
  return hasRight(user.shopPermissions ?? [], manageRight(area));
}

/**
 * Map a dashboard path to the permission area that guards it — mirrors the
 * backend route→area table (`backend/src/shared/http/merchantAreas.ts`).
 * Most-specific prefixes first. Returns null for ungated sections (the
 * dashboard home, profile, settings, categories) which everyone may reach.
 */
const PATH_AREAS: readonly [string, Area][] = [
  ["/dashboard/products", "products"],
  ["/dashboard/custom-fields", "products"],
  ["/dashboard/orders", "orders"],
  ["/dashboard/returns", "orders"],
  ["/dashboard/invoices", "invoices"],
  ["/dashboard/quotations", "invoices"],
  ["/dashboard/challans", "invoices"],
  ["/dashboard/caution-requests", "invoices"],
  ["/dashboard/payments", "payments"],
  ["/dashboard/parties", "parties"],
  ["/dashboard/stock-adjustments", "stock"],
  ["/dashboard/vendors", "vendors"],
  ["/dashboard/carousels", "marketing"],
  ["/dashboard/flash-deals", "marketing"],
  ["/dashboard/spotlight", "marketing"],
  ["/dashboard/promotions", "marketing"],
  ["/dashboard/coupons", "marketing"],
  ["/dashboard/shop", "shop"],
  ["/dashboard/reports", "reports"],
  ["/dashboard/analytics", "reports"],
  ["/dashboard/payouts", "payouts"],
  ["/dashboard/team", "team"],
];

export function areaForPath(pathname: string): Area | null {
  if (pathname === "/dashboard") return "dashboard";
  for (const [prefix, area] of PATH_AREAS) {
    if (pathname === prefix || pathname.startsWith(`${prefix}/`)) return area;
  }
  return null;
}
