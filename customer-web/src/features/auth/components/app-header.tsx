"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  Bell,
  Heart,
  LogOut,
  Package,
  Search,
  ShoppingCart,
  Store,
  User,
} from "lucide-react";
import { useAuth } from "../auth-context";
import { useNotifications } from "@/features/notifications/notifications-context";
import { useCart } from "@/features/cart/cart-context";
import { Avatar } from "./avatar";
import { useEffect, useRef, useState } from "react";

// ── Merchant-links badge (Merchants nav item) ────────────────────────────────

/**
 * Lightweight hook: fetches /api/me/links once when authed, returns whether
 * any linked shop exists. Silently swallows errors (the link just won't show).
 */
function useMerchantLinksExist(): boolean {
  const { status } = useAuth();
  const [hasLinks, setHasLinks] = useState(false);

  useEffect(() => {
    if (status !== "authed") return;
    void fetch("/api/me/links", { cache: "no-store" })
      .then(async (res) => {
        if (!res.ok) return;
        const body = (await res.json()) as { data?: unknown[] };
        if (Array.isArray(body?.data) && body.data.length > 0) {
          setHasLinks(true);
        }
      })
      .catch(() => {
        /* silent */
      });
  }, [status]);

  return hasLinks;
}

// ── Search form (submits to /search?q=) ──────────────────────────────────────

function SearchInput() {
  const router = useRouter();
  const [q, setQ] = useState("");

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = q.trim();
    if (!trimmed) return;
    router.push(`/search?q=${encodeURIComponent(trimmed)}`);
  }

  return (
    <form
      onSubmit={handleSubmit}
      role="search"
      className="relative hidden sm:flex"
    >
      <label htmlFor="header-search" className="sr-only">
        Search ShopXY
      </label>
      <span className="pointer-events-none absolute inset-y-0 left-md flex items-center">
        <Search size={16} className="text-muted" aria-hidden />
      </span>
      <input
        id="header-search"
        type="search"
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder="Search ShopXY…"
        className="h-9 w-40 rounded-input border border-hairline bg-canvas pl-[36px] pr-md text-body-md text-ink placeholder:text-subtle focus:w-56 focus:outline-none focus:ring-2 focus:ring-brand-soft lg:w-56 lg:focus:w-72 transition-all"
      />
    </form>
  );
}

// ── Cart badge ────────────────────────────────────────────────────────────────

function CartBadge({ count }: { count: number }) {
  return (
    <Link
      href="/cart"
      aria-label={count > 0 ? `Cart (${count} item${count === 1 ? "" : "s"})` : "Cart"}
      className="relative flex size-9 shrink-0 items-center justify-center rounded-sm text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <ShoppingCart size={20} aria-hidden />
      {count > 0 ? (
        <span
          className="absolute -right-0.5 -top-0.5 inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-brand px-[3px] text-[9px] font-extrabold leading-none text-white ring-2 ring-canvas"
          aria-hidden
        >
          {count > 99 ? "99+" : count}
        </span>
      ) : null}
    </Link>
  );
}

// ── Account dropdown ──────────────────────────────────────────────────────────

function AccountMenu({
  user,
  onSignOut,
}: {
  user: { name: string; avatarUrl?: string | null };
  onSignOut: () => void;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // Close on outside click.
  useEffect(() => {
    if (!open) return;
    function handler(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  // Close on Escape.
  useEffect(() => {
    if (!open) return;
    function handler(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [open]);

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        aria-label="Account menu"
        aria-expanded={open}
        aria-haspopup="menu"
        onClick={() => setOpen((v) => !v)}
        className="shrink-0 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <Avatar url={user.avatarUrl} name={user.name} size={30} />
      </button>

      {open ? (
        <div
          role="menu"
          className="absolute right-0 top-full z-50 mt-xs w-44 rounded-md border border-hairline bg-white py-xs shadow-menu"
        >
          <MenuLink href="/account" icon={<User size={15} />} onClick={() => setOpen(false)}>
            Account
          </MenuLink>
          <MenuLink href="/orders" icon={<Package size={15} />} onClick={() => setOpen(false)}>
            Orders
          </MenuLink>
          <MenuLink href="/wishlist" icon={<Heart size={15} />} onClick={() => setOpen(false)}>
            Wishlist
          </MenuLink>
          <div className="my-xs border-t border-hairline" />
          <button
            role="menuitem"
            type="button"
            onClick={() => {
              setOpen(false);
              onSignOut();
            }}
            className="flex w-full items-center gap-sm px-md py-sm text-label-md text-error transition-colors hover:bg-error-soft focus-visible:outline-none focus-visible:ring-inset focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <LogOut size={15} aria-hidden />
            Sign out
          </button>
        </div>
      ) : null}
    </div>
  );
}

function MenuLink({
  href,
  icon,
  onClick,
  children,
}: {
  href: string;
  icon: React.ReactNode;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <Link
      role="menuitem"
      href={href}
      onClick={onClick}
      className="flex items-center gap-sm px-md py-sm text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-inset focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="shrink-0 text-muted">{icon}</span>
      {children}
    </Link>
  );
}

// ── Main header ───────────────────────────────────────────────────────────────

/**
 * App-wide top bar. Extends the original signed-in-only header with:
 *   - Brand logo (links to home feed)
 *   - Search input → /search?q=
 *   - Cart badge from useCart()
 *   - Orders link
 *   - Wishlist link
 *   - Merchants link (shown only when the user has linked shops)
 *   - Notification bell with unread badge
 *   - Account dropdown (profile, orders, wishlist, sign-out)
 *   - Guest: Sign in / Register links instead of the account menu
 *
 * Mobile-responsive: search collapses to icon, labels hide, links collapse
 * into the account menu on narrow viewports.
 */
export function AppHeader() {
  const { user, status, logout } = useAuth();
  const { unread } = useNotifications();
  const { count: cartCount } = useCart();
  const hasLinks = useMerchantLinksExist();
  const router = useRouter();
  const pathname = usePathname();

  async function onSignOut() {
    await logout();
    router.replace("/login");
  }

  const isAuthed = status === "authed";

  return (
    <header className="sticky top-0 z-40 border-b border-hairline bg-canvas/95 backdrop-blur-sm">
      <div className="mx-auto flex h-14 max-w-shell items-center gap-md px-lg">
        {/* Brand */}
        <Link href="/" aria-label="ShopXY home" className="flex shrink-0 items-center gap-sm">
          <span className="flex size-7 items-center justify-center rounded-sm bg-brand">
            <Store size={16} className="text-white" aria-hidden />
          </span>
          <span className="hidden text-[18px] font-extrabold leading-none sm:block">
            <span className="text-ink">shop</span>
            <span className="text-brand">xy</span>
            <span className="text-brand">.</span>
          </span>
        </Link>

        {/* Search */}
        <SearchInput />

        {/* Spacer */}
        <span className="flex-1" />

        {/* Nav links — desktop */}
        {isAuthed ? (
          <nav className="hidden items-center gap-xs md:flex">
            <NavLink href="/orders" active={pathname.startsWith("/orders")}>
              Orders
            </NavLink>
            <NavLink href="/wishlist" active={pathname === "/wishlist"}>
              Wishlist
            </NavLink>
            {hasLinks ? (
              <NavLink href="/merchants" active={pathname.startsWith("/merchants")}>
                Merchants
              </NavLink>
            ) : null}
          </nav>
        ) : null}

        {/* Icon actions row */}
        <div className="flex items-center gap-xs">
          {/* Cart */}
          <CartBadge count={cartCount} />

          {isAuthed ? (
            <>
              {/* Notifications */}
              <Link
                href="/dashboard/notifications"
                aria-label={
                  unread > 0 ? `Notifications (${unread} unread)` : "Notifications"
                }
                className="relative flex size-9 shrink-0 items-center justify-center rounded-sm text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                <Bell size={20} aria-hidden />
                {unread > 0 ? (
                  <span
                    className="absolute -right-0.5 -top-0.5 inline-flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-error px-[3px] text-[9px] font-extrabold leading-none text-white ring-2 ring-canvas"
                    aria-hidden
                  >
                    {unread > 99 ? "99+" : unread}
                  </span>
                ) : null}
              </Link>

              {/* Account dropdown */}
              <AccountMenu user={user!} onSignOut={onSignOut} />
            </>
          ) : (
            /* Guest: sign in + register */
            <div className="flex items-center gap-sm">
              <Link
                href="/login"
                className="hidden text-label-md text-muted transition-colors hover:text-ink focus-visible:outline-none sm:block"
              >
                Sign in
              </Link>
              <Link
                href="/register"
                className="inline-flex h-8 items-center rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                Register
              </Link>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

function NavLink({
  href,
  active,
  children,
}: {
  href: string;
  active: boolean;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      aria-current={active ? "page" : undefined}
      className={`rounded-sm px-sm py-xs text-label-md transition-colors hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
        active ? "text-ink" : "text-muted"
      }`}
    >
      {children}
    </Link>
  );
}
