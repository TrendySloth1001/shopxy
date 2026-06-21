"use client";

import Link from "next/link";
import Image from "next/image";
import {
  Store,
  ReceiptText,
  FileText,
  ArrowRight,
} from "lucide-react";
import type { Party, Vendor, MerchantRole } from "../types";
import { merchantBase, roleLabelOf, roleColorOf } from "../types";
import { formatINR } from "@/shared/format";
import { formatRelativeTime } from "@/shared/datetime";

// ─── Logo ──────────────────────────────────────────────────────────────────

function ShopLogo({ logoUrl, initial }: { logoUrl?: string | null; initial: string }) {
  const src = logoUrl
    ? logoUrl.startsWith("/images/")
      ? `/api/media${logoUrl}`
      : logoUrl
    : null;

  return (
    <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-md border border-hairline bg-white shadow-floating">
      {src ? (
        <Image src={src} alt="" fill className="object-cover" sizes="56px" />
      ) : (
        <div className="flex h-full w-full items-center justify-center bg-brand-soft">
          <span className="text-title-lg font-black text-brand">{initial}</span>
        </div>
      )}
    </div>
  );
}

// ─── Banner ────────────────────────────────────────────────────────────────

function CardBanner({ bannerUrl }: { bannerUrl?: string | null }) {
  const src = bannerUrl
    ? bannerUrl.startsWith("/images/")
      ? `/api/media${bannerUrl}`
      : bannerUrl
    : null;

  if (src) {
    return (
      <div className="relative h-20 w-full overflow-hidden">
        <Image src={src} alt="" fill className="object-cover" sizes="(max-width: 640px) 100vw, 600px" />
        <div className="absolute inset-0 bg-gradient-to-b from-transparent to-black/20" />
      </div>
    );
  }
  return (
    <div className="flex h-20 w-full items-center justify-end bg-gradient-to-br from-brand-soft to-hero-panel px-lg">
      <Store size={32} className="text-brand opacity-60" />
    </div>
  );
}

// ─── Quick-links strip ─────────────────────────────────────────────────────

type QuickLink = { href: string; icon: React.ReactNode; label: string };

function QuickLinks({ links }: { links: QuickLink[] }) {
  return (
    <div className="flex items-center gap-xs border-t border-hairline pt-sm">
      {links.map((l) => (
        <Link
          key={l.href}
          href={l.href}
          className="inline-flex flex-1 flex-col items-center gap-[3px] rounded-sm py-sm text-center hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          <span className="text-brand">{l.icon}</span>
          <span className="text-[11px] font-bold text-muted">{l.label}</span>
        </Link>
      ))}
    </div>
  );
}

// ─── MerchantCard ─────────────────────────────────────────────────────────

type MerchantCardProps = {
  item: Party | Vendor;
  role: MerchantRole;
};

export function MerchantCard({ item, role }: MerchantCardProps) {
  const shop = item.shop;
  const shopName = shop?.name ?? item.name;
  const logoUrl = shop?.logoUrl ?? null;
  const bannerUrl = shop?.bannerUrl ?? null;
  const initial = shopName.trim()[0]?.toUpperCase() ?? "?";
  const invoiceCount = item._count?.invoices ?? 0;
  const base = merchantBase(role, item.id);

  // Last invoice activity
  const lastInvoice = item.invoices?.[0] ?? null;
  const activityText = lastInvoice
    ? `Last invoice ${formatRelativeTime(lastInvoice.invoiceDate ?? undefined)}${
        lastInvoice.total != null ? ` · ${formatINR(lastInvoice.total)}` : ""
      }`
    : "No activity yet";

  const isParty = role === "party";

  const quickLinks: QuickLink[] = [
    {
      href: `${base}/catalog`,
      icon: <Store size={16} />,
      label: "Catalog",
    },
    {
      href: `${base}/invoices`,
      icon: <ReceiptText size={16} />,
      label: "Invoices",
    },
    ...(isParty
      ? [
          {
            href: `${base}/quotations`,
            icon: <FileText size={16} />,
            label: "Quotes",
          },
        ]
      : []),
  ];

  // NOTE: the card must NOT itself be a <Link> — the quick-links strip renders
  // links inside it, and <a> nested in <a> is invalid HTML (hydration error).
  // The banner + title area carries the catalog link instead.
  return (
    <div className="overflow-hidden rounded-lg border border-hairline bg-white hover:shadow-floating focus-within:ring-2 focus-within:ring-brand transition-shadow">
      <Link
        href={`${base}/catalog`}
        className="block focus-visible:outline-none"
      >
        {/* Banner */}
        <CardBanner bannerUrl={bannerUrl} />
      </Link>

      {/* Card body */}
      <div className="px-md pb-md">
        {/* Logo + title row: logo overlaps banner */}
        <div className="-mt-7 flex items-start gap-md">
          <ShopLogo logoUrl={logoUrl} initial={initial} />
          <div className="min-w-0 flex-1 pt-md">
            <Link
              href={`${base}/catalog`}
              className="focus-visible:outline-none"
            >
              <p className="text-title-sm font-extrabold leading-tight text-ink line-clamp-1">
                {shopName}
              </p>
            </Link>
            <div className="mt-[2px] flex flex-wrap items-center gap-xs">
              {/* Role pill */}
              <span
                className={`inline-block rounded-full px-sm py-[2px] text-[11px] font-extrabold ${roleColorOf(role)}`}
              >
                {roleLabelOf(role)}
              </span>
              <span className="text-disabled">·</span>
              <span className="text-body-sm text-muted">
                {invoiceCount === 0
                  ? "No invoices yet"
                  : `${invoiceCount} invoice${invoiceCount === 1 ? "" : "s"}`}
              </span>
            </div>
          </div>
          <ArrowRight size={16} className="mt-md flex-shrink-0 text-muted" />
        </div>

        {/* Activity line */}
        <div className="mt-xs flex items-center gap-xs">
          <ReceiptText size={13} className="flex-shrink-0 text-muted" />
          <p className="text-body-sm text-muted line-clamp-1">{activityText}</p>
        </div>

        {/* Quick-links strip */}
        <div className="mt-sm">
          <QuickLinks links={quickLinks} />
        </div>
      </div>
    </div>
  );
}

// ─── Skeleton ──────────────────────────────────────────────────────────────

export function MerchantCardSkeleton() {
  return (
    <div className="overflow-hidden rounded-lg border border-hairline bg-white">
      <div className="h-20 animate-pulse bg-hero-panel" />
      <div className="px-md pb-md">
        <div className="-mt-7 flex items-start gap-md">
          <div className="h-14 w-14 flex-shrink-0 animate-pulse rounded-md bg-hero-panel" />
          <div className="flex-1 pt-md">
            <div className="h-4 w-3/4 animate-pulse rounded-full bg-hero-panel" />
            <div className="mt-xs flex gap-xs">
              <div className="h-3 w-16 animate-pulse rounded-full bg-hero-panel" />
              <div className="h-3 w-20 animate-pulse rounded-full bg-hero-panel" />
            </div>
          </div>
        </div>
        <div className="mt-sm h-3 w-1/2 animate-pulse rounded-full bg-hero-panel" />
        <div className="mt-sm flex gap-xs border-t border-hairline pt-sm">
          {[0, 1, 2].map((i) => (
            <div key={i} className="h-10 flex-1 animate-pulse rounded-sm bg-hero-panel" />
          ))}
        </div>
      </div>
    </div>
  );
}
