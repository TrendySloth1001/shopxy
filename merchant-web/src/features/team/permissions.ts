/**
 * Permission catalog — mirrors `backend/src/shared/http/permissions.ts`.
 * A right is `"<area>:<action>"`; `manage` implies `view`. `dashboard` and
 * `reports` are view-only. Keep in lockstep with the backend AREAS list.
 */
export const AREAS = [
  "dashboard",
  "products",
  "orders",
  "invoices",
  "payments",
  "parties",
  "stock",
  "vendors",
  "marketing",
  "shop",
  "reports",
  "payouts",
  "team",
] as const;
export type Area = (typeof AREAS)[number];

export const AREA_LABELS: Record<Area, string> = {
  dashboard: "Dashboard",
  products: "Products",
  orders: "Orders",
  invoices: "Invoices",
  payments: "Payments",
  parties: "Parties",
  stock: "Stock",
  vendors: "Vendors",
  marketing: "Marketing",
  shop: "Shop",
  reports: "Reports",
  payouts: "Payouts",
  team: "Team",
};

/** Areas with no write surface — only `:view` exists. */
export const VIEW_ONLY: ReadonlySet<Area> = new Set<Area>(["dashboard", "reports"]);

export const viewRight = (area: Area) => `${area}:view`;
export const manageRight = (area: Area) => `${area}:manage`;

/** Ensure every `:manage` carries its `:view`, sorted + de-duped. */
export function normalizeRights(rights: Iterable<string>): string[] {
  const out = new Set<string>();
  for (const r of rights) {
    out.add(r);
    if (r.endsWith(":manage")) out.add(r.replace(":manage", ":view"));
  }
  return [...out].sort();
}

export function hasRight(rights: readonly string[], right: string): boolean {
  if (rights.includes(right)) return true;
  if (right.endsWith(":view")) return rights.includes(right.replace(":view", ":manage"));
  return false;
}

/** Summarise a grant set, e.g. "Products, Orders +2". */
export function summariseRights(rights: readonly string[]): string {
  const areas = AREAS.filter((a) => hasRight(rights, viewRight(a)));
  if (areas.length === 0) return "No access";
  const labels = areas.map((a) => AREA_LABELS[a]);
  if (labels.length <= 3) return labels.join(", ");
  return `${labels.slice(0, 3).join(", ")} +${labels.length - 3}`;
}
