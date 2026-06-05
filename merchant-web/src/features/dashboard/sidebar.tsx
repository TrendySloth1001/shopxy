"use client";

import { useSyncExternalStore } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { PanelLeft, PanelLeftClose, LogOut } from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";
import { Avatar } from "@/features/auth/components/avatar";
import { Divider } from "@/shared/ui/divider";
import { NAV_GROUPS, hrefForNav, type NavItem } from "./nav-items";

const STORAGE_KEY = "sx_sidebar_collapsed";

/**
 * Persisted collapse preference, read via useSyncExternalStore so the server
 * snapshot (expanded) and client value reconcile without a hydration mismatch
 * or a setState-in-effect. A synthetic "storage" event re-syncs the same tab.
 */
function useCollapsed(): [boolean, () => void] {
  const collapsed = useSyncExternalStore(
    (cb) => {
      window.addEventListener("storage", cb);
      return () => window.removeEventListener("storage", cb);
    },
    () => localStorage.getItem(STORAGE_KEY) === "1",
    () => false,
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

  async function onSignOut() {
    await logout();
    router.replace("/login");
  }

  const groups = NAV_GROUPS.filter(
    (g) => !g.adminOnly || user?.isPlatformAdmin,
  );

  function isActive(href: string): boolean {
    if (href === "/dashboard") return pathname === "/dashboard";
    return pathname === href || pathname.startsWith(`${href}/`);
  }

  return (
    <aside
      className={`sticky top-0 flex h-dvh shrink-0 flex-col border-r border-hairline bg-canvas transition-[width] duration-medium ${
        collapsed ? "w-16" : "w-64"
      }`}
    >
      {/* Brand + collapse toggle */}
      <div
        className={`flex h-14 items-center gap-md px-md ${collapsed ? "justify-center" : ""}`}
      >
        <span className="flex size-8 shrink-0 items-center justify-center rounded-md bg-ink text-label-lg text-white">
          S
        </span>
        {!collapsed ? (
          <span className="flex-1 truncate text-label-lg text-ink">
            ShopXY <span className="text-subtle">· Merchant</span>
          </span>
        ) : null}
        {!collapsed ? (
          <button
            type="button"
            onClick={toggle}
            aria-label="Collapse sidebar"
            className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <PanelLeftClose size={18} />
          </button>
        ) : null}
      </div>

      {collapsed ? (
        <div className="flex justify-center pb-sm">
          <button
            type="button"
            onClick={toggle}
            aria-label="Expand sidebar"
            className="rounded-md p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <PanelLeft size={18} />
          </button>
        </div>
      ) : null}

      <Divider />

      {/* Scrollable nav */}
      <nav className="flex-1 overflow-y-auto px-sm py-md">
        {groups.map((group, gi) => (
          <div key={group.title ?? "primary"} className="mb-md">
            {group.title ? (
              collapsed ? (
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
                    collapsed={collapsed}
                  />
                </li>
              ))}
            </ul>
          </div>
        ))}
      </nav>

      <Divider />

      {/* Footer: identity + sign out */}
      <div className={`flex items-center gap-sm p-md ${collapsed ? "justify-center" : ""}`}>
        <Link
          href={hrefForNav("profile")}
          title={collapsed ? user?.name ?? "Profile" : undefined}
          className={`flex min-w-0 items-center gap-sm rounded-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
            collapsed ? "" : "flex-1 p-xs"
          }`}
        >
          <Avatar url={user?.avatarUrl} name={user?.name ?? ""} size={32} />
          {!collapsed ? (
            <span className="flex min-w-0 flex-1 flex-col">
              <span className="truncate text-body-md text-ink">{user?.name}</span>
              <span className="truncate text-body-sm text-subtle">{user?.email}</span>
            </span>
          ) : null}
        </Link>
        {!collapsed ? (
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
    </aside>
  );
}

function NavLink({
  item,
  active,
  collapsed,
}: {
  item: NavItem;
  active: boolean;
  collapsed: boolean;
}) {
  const Icon = item.icon;
  return (
    <Link
      href={hrefForNav(item.key)}
      title={collapsed ? item.label : undefined}
      aria-current={active ? "page" : undefined}
      className={`flex w-full items-center gap-md rounded-md px-sm py-sm text-left text-body-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        collapsed ? "justify-center" : ""
      } ${active ? "bg-ink text-white" : "text-ink hover:bg-surface-tint"}`}
    >
      <Icon size={18} className="shrink-0" />
      {!collapsed ? <span className="truncate">{item.label}</span> : null}
    </Link>
  );
}
