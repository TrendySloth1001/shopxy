import type { AuthUser } from "./types";
import { type Area, hasRight, manageRight, viewRight } from "@/features/team/permissions";

export function isShopOwner(user: AuthUser | null | undefined): boolean {
  return user?.shopRole === "OWNER";
}

export function canView(user: AuthUser | null | undefined, area: Area): boolean {
  if (!user) return false;
  if (isShopOwner(user)) return true;
  return hasRight(user.shopPermissions ?? [], viewRight(area));
}

export function canManage(user: AuthUser | null | undefined, area: Area): boolean {
  if (!user) return false;
  if (isShopOwner(user)) return true;
  return hasRight(user.shopPermissions ?? [], manageRight(area));
}

const PATH_AREAS: readonly [string, Area][] = [
  ["/dashboard/products", "products"],
  ["/dashboard/scan-console", "products"],
  ["/dashboard/custom-fields", "products"],
  ["/dashboard/hsn-codes", "products"],
  ["/dashboard/orders", "orders"],
  ["/dashboard/returns", "orders"],
  ["/dashboard/pos", "invoices"],
  ["/dashboard/cashier", "invoices"],
  ["/dashboard/invoices", "invoices"],
  ["/dashboard/quotations", "quotations"],
  ["/dashboard/challans", "challans"],
  ["/dashboard/payments", "payments"],
  ["/dashboard/parties", "parties"],
  ["/dashboard/stock-adjustments", "stock"],
  ["/dashboard/vendors", "vendors"],
  ["/dashboard/banners", "marketing"],
  ["/dashboard/coupons", "marketing"],
  ["/dashboard/shop", "shop"],
  ["/dashboard/reports", "reports"],
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
