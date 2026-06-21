"use client";

import Link from "next/link";
import { Store, Truck, RotateCcw, ShieldCheck, BadgePercent } from "lucide-react";

// ── Trust promise row ─────────────────────────────────────────────────────────

// Storefront promises — qualified, not blanket guarantees. Delivery, returns
// and authenticity are set per shop/SKU (a shop's returns can be disabled, an
// item may not be returnable, delivery isn't always free), so we describe the
// platform mechanics here rather than asserting an unconditional guarantee.
// (CP Act 2019 s.2(28)/(47); CCPA Dark-Patterns Guidelines 2023.)
const PROMISES = [
  { icon: ShieldCheck, label: "Secure checkout" },
  { icon: RotateCcw,   label: "Returns per shop policy" },
  { icon: Truck,        label: "Delivery set by each shop" },
  { icon: BadgePercent, label: "Compare prices across shops" },
] as const;

// ── Link columns ──────────────────────────────────────────────────────────────

const COLUMNS = [
  {
    heading: "Shop",
    links: [
      { label: "Categories",  href: "/categories" },
      { label: "Search",      href: "/search" },
    ],
  },
  {
    heading: "Your account",
    links: [
      { label: "Orders",    href: "/orders" },
      { label: "Wishlist",  href: "/wishlist" },
      { label: "Wallet",    href: "/account/wallet" },
      { label: "Addresses", href: "/account/addresses" },
    ],
  },
  {
    heading: "Help",
    links: [
      { label: "Account",       href: "/account" },
      { label: "Notifications", href: "/notifications" },
      { label: "Invitations",   href: "/invitations" },
    ],
  },
  {
    heading: "Legal",
    links: [
      { label: "Privacy Policy",     href: "/legal/privacy" },
      { label: "Terms of Service",   href: "/legal/terms" },
      { label: "Consumer Policies",  href: "/legal/policies" },
    ],
  },
] as const;

// ── Component ─────────────────────────────────────────────────────────────────

/**
 * Site-wide footer.
 *
 * Layout: responsive — stacked on mobile, 4-column grid on tablet+.
 *   col 1 — brand block (logo + tagline)
 *   col 2 — Shop links
 *   col 3 — Account links
 *   col 4 — Help links
 *
 * Below columns: hairline divider → trust-promise row → copyright line.
 *
 * Styling: bg-white, border-t hairline, muted text, hover:text-ink links.
 * No chunky borders or elevation — minimal-premium.
 */
export function SiteFooter() {
  return (
    <footer className="border-t border-hairline bg-white">
      <div className="mx-auto max-w-shell px-lg py-xxxl">

        {/* ── Column grid ──────────────────────────────────────────────── */}
        <div className="grid grid-cols-2 gap-xxxl tablet:grid-cols-3 desktop:grid-cols-5">

          {/* Brand block */}
          <div className="col-span-2 tablet:col-span-3 desktop:col-span-1">
            <Link
              href="/"
              aria-label="ShopXY home"
              className="inline-flex items-center gap-sm"
            >
              <span className="flex size-7 shrink-0 items-center justify-center rounded-sm bg-brand">
                <Store size={16} className="text-white" aria-hidden />
              </span>
              <span className="text-[18px] font-extrabold leading-none">
                <span className="text-ink">shop</span>
                <span className="text-brand">xy</span>
                <span className="text-brand">.</span>
              </span>
            </Link>
            <p className="mt-md max-w-snug text-body-sm text-muted leading-relaxed">
              Your favourite shops, deals, and brands — all in one place.
            </p>
          </div>

          {/* Link columns */}
          {COLUMNS.map((col) => (
            <div key={col.heading}>
              <h3 className="mb-md text-label-md text-ink">{col.heading}</h3>
              <ul className="space-y-sm">
                {col.links.map((l) => (
                  <li key={l.href}>
                    <Link
                      href={l.href}
                      className="text-body-sm text-muted transition-colors duration-200 hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft motion-safe:transition-colors"
                    >
                      {l.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* ── Hairline divider ─────────────────────────────────────────── */}
        <div className="my-xxl border-t border-hairline" />

        {/* ── Trust row + copyright ────────────────────────────────────── */}
        <div className="flex flex-col items-start gap-lg tablet:flex-row tablet:items-center tablet:justify-between">

          {/* Four storefront promises */}
          <ul className="flex flex-wrap gap-x-xl gap-y-sm">
            {PROMISES.map(({ icon: Icon, label }) => (
              <li key={label} className="flex items-center gap-xs text-body-sm text-muted">
                <Icon size={14} className="shrink-0 text-brand" aria-hidden />
                {label}
              </li>
            ))}
          </ul>

          {/* Copyright */}
          <p className="text-body-sm text-subtle">© 2026 ShopXY</p>
        </div>

      </div>
    </footer>
  );
}
