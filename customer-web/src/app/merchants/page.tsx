"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { Store, Mail } from "lucide-react";
import { AppHeader } from "@/features/auth/components/app-header";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { MerchantCard, MerchantCardSkeleton } from "@/features/merchants/components/merchant-card";
import { fetchLinks, fetchIncomingInvitations } from "@/features/merchants/api";
import type { Party, Vendor, MerchantRole } from "@/features/merchants/types";

// ─── Role filter ─────────────────────────────────────────────────────────────

type RoleFilter = "all" | "party" | "vendor";

type MerchantItem = { item: Party | Vendor; role: MerchantRole };

function RoleFilterBar({
  filter,
  partyCount,
  vendorCount,
  onChange,
}: {
  filter: RoleFilter;
  partyCount: number;
  vendorCount: number;
  onChange: (f: RoleFilter) => void;
}) {
  const chips: { key: RoleFilter; label: string }[] = [
    { key: "all", label: "All" },
    { key: "party", label: `Customer · ${partyCount}` },
    { key: "vendor", label: `Supplier · ${vendorCount}` },
  ];

  return (
    <div className="flex flex-wrap items-center gap-xs">
      {chips.map((c) => (
        <button
          key={c.key}
          type="button"
          onClick={() => onChange(c.key)}
          className={`inline-flex items-center rounded-full px-md py-sm text-label-lg font-extrabold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
            filter === c.key
              ? "bg-ink text-white"
              : "border border-hairline bg-white text-ink hover:bg-surface-tint"
          }`}
        >
          {c.label}
        </button>
      ))}
    </div>
  );
}

// ─── Pending invites banner ─────────────────────────────────────────────────

function PendingInvitesBanner({ count }: { count: number }) {
  return (
    <Link
      href="/invitations"
      className="flex items-center gap-md rounded-md border border-brand bg-brand-soft px-md py-md hover:bg-brand-soft/80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
    >
      <div className="flex h-xxl w-xxl flex-shrink-0 items-center justify-center rounded-full bg-brand">
        <Mail size={14} className="text-white" />
      </div>
      <span className="flex-1 text-body-sm font-extrabold text-brand-strong">
        {count === 1 ? "1 pending invitation" : `${count} pending invitations`}
      </span>
      <svg
        className="h-4 w-4 flex-shrink-0 text-brand-strong"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        aria-hidden
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
      </svg>
    </Link>
  );
}

// ─── Empty state ─────────────────────────────────────────────────────────────

function EmptyState() {
  return (
    <div className="flex flex-col items-center py-massive text-center">
      <div className="mb-lg flex h-24 w-24 items-center justify-center rounded-xl bg-brand-soft">
        <Store size={40} className="text-brand" />
      </div>
      <p className="text-title-md font-extrabold text-ink">No linked merchants yet</p>
      <p className="mt-xs max-w-sm text-body-md text-muted">
        When a shop adds you as a customer or supplier, they&apos;ll appear here with
        all their invoices.
      </p>
      <div className="mt-xl">
        <Link
          href="/invitations"
          className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-xl text-label-lg font-extrabold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
        >
          <Mail size={16} />
          View invitations
        </Link>
      </div>
    </div>
  );
}

// ─── Main content ─────────────────────────────────────────────────────────────

function MerchantsContent() {
  const [items, setItems] = useState<MerchantItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<RoleFilter>("all");
  const [pendingCount, setPendingCount] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [links, invPage] = await Promise.all([
        fetchLinks(),
        fetchIncomingInvitations({ status: "PENDING", limit: 1 }).catch(() => null),
      ]);
      setPendingCount(invPage?.total ?? 0);
      const list: MerchantItem[] = [
        ...links.parties.map((p) => ({ item: p, role: "party" as MerchantRole })),
        ...links.vendors.map((v) => ({ item: v, role: "vendor" as MerchantRole })),
      ];
      // Sort: most recently active first, then by name
      list.sort((a, b) => {
        const aDate = a.item.invoices?.[0]?.invoiceDate ?? null;
        const bDate = b.item.invoices?.[0]?.invoiceDate ?? null;
        if (!aDate && !bDate) return a.item.name.localeCompare(b.item.name);
        if (!aDate) return 1;
        if (!bDate) return -1;
        return new Date(bDate).getTime() - new Date(aDate).getTime();
      });
      setItems(list);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load your merchants.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function run() { await load(); }
    if (!cancelled) void run();
    return () => { cancelled = true; };
  }, [load]);

  const partyCount = items.filter((i) => i.role === "party").length;
  const vendorCount = items.filter((i) => i.role === "vendor").length;
  const showFilter = partyCount > 0 && vendorCount > 0;

  const visible =
    filter === "all" ? items : items.filter((i) => i.role === filter);

  // ── Error ──────────────────────────────────────────────────────────────
  if (error && items.length === 0) {
    return (
      <div className="mx-auto max-w-content px-lg py-massive text-center">
        <p className="text-title-sm font-bold text-ink mb-xs">
          Could not load your merchants
        </p>
        <p className="text-body-sm text-muted mb-xl">{error}</p>
        <button
          onClick={() => void load()}
          className="inline-flex h-10 items-center rounded-button border border-hairline px-xl text-label-lg font-bold text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
        >
          Try again
        </button>
      </div>
    );
  }

  if (loading && items.length === 0) {
    return (
      <div className="mx-auto max-w-shell px-lg py-md">
        <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
          {[0, 1, 2].map((i) => (
            <MerchantCardSkeleton key={i} />
          ))}
        </div>
      </div>
    );
  }

  if (items.length === 0) {
    return (
      <div className="mx-auto max-w-shell px-lg">
        <EmptyState />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-shell px-lg py-md">
      {/* Pending invites banner */}
      {pendingCount > 0 && (
        <div className="mb-md">
          <PendingInvitesBanner count={pendingCount} />
        </div>
      )}

      {/* Filter chips */}
      {showFilter && (
        <div className="mb-md">
          <RoleFilterBar
            filter={filter}
            partyCount={partyCount}
            vendorCount={vendorCount}
            onChange={setFilter}
          />
        </div>
      )}

      {/* Merchant grid */}
      {visible.length === 0 ? (
        <div className="py-xl text-center">
          <p className="text-body-md font-semibold text-muted">
            {filter === "party" ? "No customer links yet." : "No supplier links yet."}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-md sm:grid-cols-2 pb-lg">
          {visible.map((m) => (
            <MerchantCard key={`${m.role}-${m.item.id}`} item={m.item} role={m.role} />
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function MerchantsPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <main className="min-h-screen bg-canvas">
        {/* Page header */}
        <div className="mx-auto max-w-shell border-b border-hairline px-lg py-lg">
          <p className="text-label-md font-extrabold uppercase tracking-widest text-brand">
            Your Merchants
          </p>
          <h1 className="mt-xs text-headline-sm font-extrabold text-ink">Merchants</h1>
          <p className="mt-xs text-body-md text-muted">
            Shops that have linked you as a customer or supplier.
          </p>
        </div>

        <MerchantsContent />
      </main>
    </RequireAuth>
  );
}
