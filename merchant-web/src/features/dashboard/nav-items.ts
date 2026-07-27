import {
  LayoutDashboard,
  Package,
  Inbox,
  Bell,
  User,
  Settings,
  Store,
  Ticket,
  FolderTree,
  Truck,
  Users,
  ReceiptIndianRupee,
  MessageSquareQuote,
  PackageCheck,
  SlidersHorizontal,
  Undo2,
  FileText,
  BarChart3,
  Images,
  ScanLine,
  CreditCard,
  Calculator,
  Network,
  Landmark,
  Percent,
  ShieldCheck,
  UserCog,
  type LucideIcon,
} from "@/shared/icons";

export type NavItem = {
  /** Stable key used for active state. */
  key: string;
  label: string;
  icon: LucideIcon;
};

export type NavGroup = {
  /** Section heading; null for the top (primary) group. */
  title: string | null;
  /** Only shown to platform admins. */
  adminOnly?: boolean;
  items: NavItem[];
};

/**
 * Merchant navigation, mirroring the Flutter app shell
 * (`frontend/lib/core/router/app_shell.dart`): 4 primary destinations plus the
 * Manage / Operations shortcut groups, and the platform-admin tools.
 *
 * Buttons only for now — selecting an item sets the active section; the
 * destination screens are not built yet.
 */
export const NAV_GROUPS: NavGroup[] = [
  {
    title: null,
    items: [
      { key: "dashboard", label: "Dashboard", icon: LayoutDashboard },
      { key: "products", label: "Products", icon: Package },
      { key: "orders", label: "Orders", icon: Inbox },
      { key: "notifications", label: "Notifications", icon: Bell },
      { key: "profile", label: "Profile", icon: User },
      { key: "settings", label: "Settings", icon: Settings },
    ],
  },
  {
    title: "Manage",
    items: [
      { key: "shop", label: "My Shop", icon: Store },
      { key: "banners", label: "Banners", icon: Images },
      { key: "coupons", label: "Coupons", icon: Ticket },
      { key: "categories", label: "Categories", icon: FolderTree },
      { key: "hsn-codes", label: "HSN codes", icon: Percent },
      { key: "vendors", label: "Vendors", icon: Truck },
      { key: "parties", label: "Parties", icon: Users },
    ],
  },
  {
    title: "Shop operations",
    items: [
      { key: "pos", label: "Point of sale", icon: CreditCard },
      { key: "cashier", label: "Cashier", icon: Calculator },
      { key: "scan-console", label: "Scan console", icon: ScanLine },
      { key: "team", label: "Team", icon: UserCog },
    ],
  },
  {
    title: "Operations",
    items: [
      // Distinct silhouettes so the three document types don't read alike:
      // a rupee receipt (a bill you issue), a quote bubble (a price quote),
      // and a checked package (a goods-dispatch challan).
      { key: "invoices", label: "Invoices", icon: ReceiptIndianRupee },
      { key: "quotations", label: "Quotations", icon: MessageSquareQuote },
      { key: "challans", label: "Challans", icon: PackageCheck },
      { key: "stock-adjustments", label: "Stock adjustments", icon: SlidersHorizontal },
      { key: "returns", label: "Returns", icon: Undo2 },
      { key: "reports", label: "Reports", icon: FileText },
      { key: "analytics", label: "Analytics", icon: BarChart3 },
    ],
  },
  {
    title: "Platform admin",
    adminOnly: true,
    items: [
      { key: "admin-taxonomy", label: "Category taxonomy", icon: Network },
      { key: "admin-bank-offers", label: "Bank offers", icon: Landmark },
      { key: "admin-shops", label: "Shop verification", icon: ShieldCheck },
    ],
  },
];

/** Flat lookup of label by key — used by the content area placeholder. */
export const NAV_LABELS: Record<string, string> = Object.fromEntries(
  NAV_GROUPS.flatMap((g) => g.items.map((i) => [i.key, i.label])),
);

/** Route for a nav key. Dashboard is the index; everything else nests under it. */
export function hrefForNav(key: string): string {
  return key === "dashboard" ? "/dashboard" : `/dashboard/${key}`;
}
