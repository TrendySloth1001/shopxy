export const AREAS = [
  "dashboard",
  "products",
  "orders",
  "invoices",
  "quotations",
  "challans",
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
  invoices: "Billing & POS",
  quotations: "Quotations",
  challans: "Challans",
  payments: "Payments",
  parties: "Customers",
  stock: "Stock",
  vendors: "Vendors",
  marketing: "Marketing",
  shop: "Shop",
  reports: "Reports",
  payouts: "Payouts",
  team: "Team",
};

export const AREA_HINTS: Record<Area, string> = {
  dashboard: "Home overview",
  products: "Catalogue, prices, stock items",
  orders: "Online orders inbox",
  invoices: "Point of sale (till), bills, returns, cashier shifts",
  quotations: "Price quotes / estimates sent to customers",
  challans: "Delivery / dispatch challans for goods",
  payments: "Receipts & payments",
  parties: "Customers & suppliers",
  stock: "Stock in / out & adjustments",
  vendors: "Vendors / suppliers",
  marketing: "Banners & coupons",
  shop: "Shop profile & settings",
  reports: "Sales reports",
  payouts: "Razorpay payouts",
  team: "Team members & roles",
};

export const VIEW_ONLY: ReadonlySet<Area> = new Set<Area>(["dashboard", "reports"]);

export const viewRight = (area: Area) => `${area}:view`;
export const manageRight = (area: Area) => `${area}:manage`;

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

export function summariseRights(rights: readonly string[]): string {
  const areas = AREAS.filter((a) => hasRight(rights, viewRight(a)));
  if (areas.length === 0) return "No access";
  const labels = areas.map((a) => AREA_LABELS[a]);
  if (labels.length <= 3) return labels.join(", ");
  return `${labels.slice(0, 3).join(", ")} +${labels.length - 3}`;
}

export function summaryAreas(rights: readonly string[]): Area[] {
  return AREAS.filter((a) => hasRight(rights, viewRight(a)));
}
