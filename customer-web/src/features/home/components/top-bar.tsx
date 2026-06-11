"use client";

import Link from "next/link";
import { Bell, ChevronDown, MapPin, Search, ShoppingCart, Store } from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";
import { useNotifications } from "@/features/notifications/notifications-context";
import { useCart } from "@/features/cart/cart-context";
import { Avatar } from "@/features/auth/components/avatar";
import { SEARCH_HINTS, useRotatingHint } from "./search-bar";

/**
 * Home top bar — port of `HomeTopBar`. Brand wordmark + a delivery-location row
 * that collapses on scroll, with a notification bell (unread badge) and profile
 * avatar pinned right. When collapsed, a compact inline search appears beside
 * the brand mark (mirroring the mobile collapse behaviour).
 *
 * Note: the mobile bar also shows a delivery address and a pending-payment
 * wallet badge — both depend on the addresses/orders features which this web
 * app does not have yet (tracked in PENDING.md), so the location row links to
 * the account page and the wallet badge is omitted.
 */
export function TopBar({ collapsed }: { collapsed: boolean }) {
  const { user, status } = useAuth();
  const { unread } = useNotifications();
  const { count: cartCount } = useCart();
  const hint = useRotatingHint();

  return (
    <div className="px-lg pb-sm pt-md">
      <div className="flex items-center gap-md">
        <Link href="/" aria-label="ShopXY home" className="flex shrink-0 items-center gap-sm">
          <span className="flex size-7 items-center justify-center rounded-sm bg-brand">
            <Store size={18} className="text-white" aria-hidden />
          </span>
          {!collapsed ? (
            <span className="text-[22px] font-extrabold leading-none">
              <span className="text-ink">shop</span>
              <span className="text-brand">xy</span>
              <span className="text-brand">.</span>
            </span>
          ) : null}
        </Link>

        {collapsed ? (
          <Link
            href="/search"
            className="flex h-9 min-w-0 flex-1 items-center gap-sm rounded-sm border border-hairline bg-white px-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Search size={18} className="shrink-0 text-muted" aria-hidden />
            <span className="line-clamp-1 text-[13px] text-muted">{SEARCH_HINTS[hint]}</span>
          </Link>
        ) : (
          <span className="flex-1" />
        )}

        <Link
          href="/cart"
          aria-label={cartCount > 0 ? `Cart (${cartCount} items)` : "Cart"}
          className="relative flex size-9 shrink-0 items-center justify-center rounded-sm border border-hairline bg-white text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <ShoppingCart size={20} aria-hidden />
          {cartCount > 0 ? (
            <span className="absolute -right-1 -top-1 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-brand px-[3px] text-[9px] font-extrabold leading-none text-white ring-2 ring-canvas">
              {cartCount > 99 ? "99+" : cartCount}
            </span>
          ) : null}
        </Link>

        <Link
          href="/notifications"
          aria-label={unread > 0 ? `Notifications (${unread} unread)` : "Notifications"}
          className="relative flex size-9 shrink-0 items-center justify-center rounded-sm border border-hairline bg-white text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Bell size={20} aria-hidden />
          {unread > 0 ? (
            <span className="absolute -right-1 -top-1 inline-flex h-4 min-w-4 items-center justify-center rounded-full bg-brand px-[3px] text-[9px] font-extrabold leading-none text-white ring-2 ring-canvas">
              {unread > 99 ? "99+" : unread}
            </span>
          ) : null}
        </Link>

        {status === "authed" ? (
          <Link
            href="/account"
            aria-label="Account"
            className="shrink-0 rounded-full focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Avatar url={user?.avatarUrl} name={user?.name ?? ""} size={34} />
          </Link>
        ) : (
          <Link
            href="/login"
            className="shrink-0 rounded-full bg-brand px-md py-[6px] text-[12px] font-bold text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            Sign in
          </Link>
        )}
      </div>

      <div
        className="overflow-hidden transition-all duration-200"
        style={{ maxHeight: collapsed ? 0 : 40, opacity: collapsed ? 0 : 1 }}
        aria-hidden={collapsed}
      >
        <Link
          href="/account"
          className="mt-sm flex items-center gap-[6px] focus-visible:outline-none"
        >
          <MapPin size={16} className="text-brand" aria-hidden />
          <span className="text-[12.5px] font-semibold text-muted">Deliver to</span>
          <span className="text-[13px] font-bold text-brand">Add a delivery address</span>
          <ChevronDown size={18} className="text-muted" aria-hidden />
        </Link>
      </div>
    </div>
  );
}
