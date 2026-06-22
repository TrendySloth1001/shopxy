"use client";

import { useState, useSyncExternalStore } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ChevronLeft, ChevronRight, LogOut, Lock, Menu, X } from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";
import { Avatar } from "@/features/auth/components/avatar";
import { useNotifications } from "@/features/notifications/notifications-context";
import { areaForPath, canView } from "@/features/auth/capabilities";
import { Divider } from "@/shared/ui/divider";
import { NAV_GROUPS, hrefForNav, type NavItem } from "./nav-items";

const STORAGE_KEY = "sx_sidebar_collapsed";

/**
 * Stable store callbacks for `useSyncExternalStore`. Hoisted to module scope so
 * their identities never change between renders — passing fresh closures would
 * make React re-subscribe after every commit (avoidable re-render churn).
 */
function subscribeCollapsed(cb: () => void): () => void {
  window.addEventListener("storage", cb);
  return () => window.removeEventListener("storage", cb);
}
const getCollapsedSnapshot = () => localStorage.getItem(STORAGE_KEY) === "1";
const getCollapsedServerSnapshot = () => false;

/**
 * Persisted collapse preference, read via useSyncExternalStore so the server
 * snapshot (expanded) and client value reconcile without a hydration mismatch
 * or a setState-in-effect. A synthetic "storage" event re-syncs the same tab.
 */
function useCollapsed(): [boolean, () => void] {
  const collapsed = useSyncExternalStore(
    subscribeCollapsed,
    getCollapsedSnapshot,
    getCollapsedServerSnapshot,
  );
  const toggle = () => {
    localStorage.setItem(STORAGE_KEY, collapsed ? "0" : "1");
    window.dispatchEvent(new Event("storage"));
  };
  return [collapsed, toggle];
}

export function Sidebar() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const [collapsed, toggle] = useCollapsed();
  const { unread } = useNotifications();
  // Styled hover tooltip for the collapsed rail. Rendered `fixed` (outside the
  // scrolling nav) so it isn't clipped by the rail's overflow.
  const [tip, setTip] = useState<{ label: string; y: number } | null>(null);
  // Mobile off-canvas drawer (the side rail is hidden < lg; nav moves to a top
  // bar + slide-in drawer).
  const [mobileOpen, setMobileOpen] = useState(false);
  const closeMobile = () => setMobileOpen(false);

  async function onSignOut() {
    await logout();
    router.replace("/login");
  }

  // Cashier kiosk lock: a plain Cashier is confined to the till — only Point of
  // sale + Cashier are shown (everything else hidden), matching a register.
  const isKiosk = user?.shopRole === "CASHIER";
  const KIOSK_KEYS = new Set(["pos", "cashier"]);
  const groups = NAV_GROUPS.filter((g) => !g.adminOnly || user?.isPlatformAdmin)
    .map((g) => (isKiosk ? { ...g, items: g.items.filter((i) => KIOSK_KEYS.has(i.key)) } : g))
    .filter((g) => g.items.length > 0);

  function isActive(href: string): boolean {
    if (href === "/dashboard") return pathname === "/dashboard";
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  /** A nav item is locked when its area exists and the user can't view it. */
  function isLocked(key: string): boolean {
    const area = areaForPath(hrefForNav(key));
    return area ? !canView(user, area) : false;
  }

  // Nav tree, reused by the desktop rail and the mobile drawer. `compact` is the
  // collapsed icon-rail mode; `onNavigate` closes the mobile drawer on click.
  const navTree = (compact: boolean, onNavigate?: () => void) => (
    <nav className="flex-1 overflow-y-auto px-sm py-md">
      {groups.map((group, gi) => (
        <div key={group.title ?? "primary"} className="mb-md">
          {group.title ? (
            compact ? (
              gi > 0 ? <Divider className="mx-auto my-sm w-6" /> : null
            ) : (
              <p className="px-sm pb-xs pt-sm text-label-md uppercase tracking-wide text-subtle">
                {group.title}
              </p>
            )
          ) : null}
          <ul className="flex flex-col gap-px">
            {group.items.map((item) => (
              <li key={item.key}>
                <NavLink
                  item={item}
                  active={isActive(hrefForNav(item.key))}
                  collapsed={compact}
                  locked={isLocked(item.key)}
                  badge={item.key === "notifications" ? unread : 0}
                  onHover={setTip}
                  onNavigate={onNavigate}
                />
              </li>
            ))}
          </ul>
        </div>
      ))}
    </nav>
  );

  const footer = (compact: boolean, onNavigate?: () => void) => (
    <div className={`flex items-center gap-sm p-md ${compact ? "justify-center" : ""}`}>
      <Link
        href={hrefForNav("profile")}
        onClick={onNavigate}
        className={`flex min-w-0 items-center gap-sm rounded-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
          compact ? "" : "flex-1 p-xs"
        }`}
      >
        <Avatar url={user?.avatarUrl} name={user?.name ?? ""} size={32} />
        {!compact ? (
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="truncate text-body-md text-ink">{user?.name}</span>
            <span className="truncate text-body-sm text-subtle">{user?.email}</span>
          </span>
        ) : null}
      </Link>
      {!compact ? (
        <button
          type="button"
          onClick={onSignOut}
          aria-label="Sign out"
          title="Sign out"
          className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <LogOut size={18} />
        </button>
      ) : null}
    </div>
  );

  const brand = (
    <span className="flex items-center gap-md">
      <span className="flex size-8 shrink-0 items-center justify-center rounded-md bg-ink text-label-lg text-white">
        S
      </span>
      <span className="truncate text-label-lg text-ink">
        ShopXY <span className="text-subtle">· Merchant</span>
      </span>
    </span>
  );

  return (
    <>
      {/* ── Desktop rail (lg+) ───────────────────────────────────────── */}
      <aside
        className={`sticky top-0 z-20 hidden h-dvh shrink-0 flex-col border-r border-hairline bg-canvas transition-[width] duration-medium lg:flex ${
          collapsed ? "w-16" : "w-64"
        }`}
      >
        <button
          type="button"
          onClick={toggle}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          aria-expanded={!collapsed}
          className="absolute -right-3 top-14 z-30 flex size-7 -translate-y-1/2 items-center justify-center rounded-full border border-hairline bg-canvas text-muted shadow-snackbar transition-colors hover:border-brand-soft hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          {collapsed ? <ChevronRight size={15} /> : <ChevronLeft size={15} />}
        </button>

        <div className={`flex h-14 items-center px-md ${collapsed ? "justify-center" : ""}`}>
          {collapsed ? (
            <span className="flex size-8 items-center justify-center rounded-md bg-ink text-label-lg text-white">S</span>
          ) : (
            brand
          )}
        </div>
        <Divider />
        {navTree(collapsed)}
        <Divider />
        {footer(collapsed)}

        {collapsed && tip ? (
          <div
            role="tooltip"
            className="pointer-events-none fixed left-16 z-50 ml-sm -translate-y-1/2 whitespace-nowrap rounded-md bg-ink px-sm py-xs text-label-md text-white shadow-floating"
            style={{ top: tip.y }}
          >
            {tip.label}
          </div>
        ) : null}
      </aside>

      {/* ── Mobile top bar (< lg) ────────────────────────────────────── */}
      <header className="sticky top-0 z-20 flex h-14 items-center gap-md border-b border-hairline bg-canvas px-md lg:hidden">
        <button
          type="button"
          onClick={() => setMobileOpen(true)}
          aria-label="Open menu"
          aria-expanded={mobileOpen}
          className="rounded-md p-xs text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Menu size={20} />
        </button>
        <span className="min-w-0 flex-1">{brand}</span>
        <Link
          href={hrefForNav("notifications")}
          aria-label="Notifications"
          className="relative rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Avatar url={user?.avatarUrl} name={user?.name ?? ""} size={28} />
          {unread > 0 ? (
            <span className="absolute -right-0.5 -top-0.5 size-2.5 rounded-full bg-error ring-2 ring-canvas" />
          ) : null}
        </Link>
      </header>

      {/* ── Mobile drawer (< lg) ─────────────────────────────────────── */}
      <div
        className={`fixed inset-0 z-50 lg:hidden ${mobileOpen ? "" : "pointer-events-none"}`}
        aria-hidden={!mobileOpen}
      >
        <button
          type="button"
          aria-label="Close menu"
          tabIndex={mobileOpen ? 0 : -1}
          onClick={closeMobile}
          className={`absolute inset-0 bg-ink/40 transition-opacity duration-medium ${mobileOpen ? "opacity-100" : "opacity-0"}`}
        />
        <div
          className={`absolute inset-y-0 left-0 flex w-72 max-w-[82%] flex-col bg-canvas shadow-floating transition-transform duration-medium ${
            mobileOpen ? "translate-x-0" : "-translate-x-full"
          }`}
        >
          <div className="flex h-14 items-center justify-between px-md">
            {brand}
            <button
              type="button"
              onClick={closeMobile}
              aria-label="Close menu"
              className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <X size={18} />
            </button>
          </div>
          <Divider />
          {navTree(false, closeMobile)}
          <Divider />
          {footer(false, closeMobile)}
        </div>
      </div>
    </>
  );
}

type HoverTip = { label: string; y: number } | null;

function NavLink({
  item,
  active,
  collapsed,
  locked,
  badge = 0,
  onHover,
  onNavigate,
}: {
  item: NavItem;
  active: boolean;
  collapsed: boolean;
  locked: boolean;
  badge?: number;
  onHover: (tip: HoverTip) => void;
  onNavigate?: () => void;
}) {
  const Icon = item.icon;
  const badgeText = badge > 99 ? "99+" : String(badge);

  // Locked: render a non-interactive row with a lock affordance instead of a
  // link, so the section stays visible but clearly out of reach (mirrors the
  // Flutter "lock instead of disappear" pattern).
  if (locked) {
    return (
      <div
        aria-disabled="true"
        title={
          collapsed
            ? `${item.label} — no access`
            : "You don’t have access. Ask the shop owner."
        }
        className={`flex w-full cursor-not-allowed items-center gap-md rounded-md px-sm py-sm text-left text-body-md text-disabled ${
          collapsed ? "justify-center" : ""
        }`}
      >
        <Icon size={18} className="shrink-0" />
        {!collapsed ? (
          <>
            <span className="flex-1 truncate">{item.label}</span>
            <Lock size={14} className="shrink-0" />
          </>
        ) : null}
      </div>
    );
  }

  const hoverProps = collapsed
    ? {
        onMouseEnter: (e: React.MouseEvent<HTMLElement>) => {
          const r = e.currentTarget.getBoundingClientRect();
          onHover({ label: item.label, y: r.top + r.height / 2 });
        },
        onMouseLeave: () => onHover(null),
        onFocus: (e: React.FocusEvent<HTMLElement>) => {
          const r = e.currentTarget.getBoundingClientRect();
          onHover({ label: item.label, y: r.top + r.height / 2 });
        },
        onBlur: () => onHover(null),
      }
    : {};

  return (
    <Link
      href={hrefForNav(item.key)}
      aria-label={collapsed ? item.label : undefined}
      aria-current={active ? "page" : undefined}
      onClick={onNavigate}
      {...hoverProps}
      className={`relative flex w-full items-center gap-md rounded-md border px-sm py-sm text-left text-body-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        collapsed ? "justify-center" : ""
      } ${active ? "border-ink bg-brand-soft font-medium text-brand-strong" : "border-transparent text-ink hover:bg-surface-tint"}`}
    >
      <span className="relative shrink-0">
        <Icon size={18} />
        {collapsed && badge > 0 ? (
          <span className="absolute -right-1 -top-1 size-2 rounded-full bg-error ring-2 ring-canvas" />
        ) : null}
      </span>
      {!collapsed ? <span className="flex-1 truncate">{item.label}</span> : null}
      {!collapsed && badge > 0 ? (
        <span className="ml-auto inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-error px-xs text-label-md text-white">
          {badgeText}
        </span>
      ) : null}
    </Link>
  );
}
