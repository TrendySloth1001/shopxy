"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ChevronRight, ClipboardList, Plus, RefreshCw, Search } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { formatDateTime } from "@/shared/datetime";
import { listChallans } from "@/features/challans/api";
import {
  CHALLAN_STATUS_CLASSES,
  CHALLAN_STATUS_LABELS,
  challanItemCount,
  type Challan,
} from "@/features/challans/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

const TABS: { key: string; label: string }[] = [
  { key: "", label: "All" },
  { key: "PENDING", label: "Pending" },
  { key: "CONVERTED", label: "Converted" },
  { key: "CANCELLED", label: "Cancelled" },
];

export default function ChallansPage() {
  const [rows, setRows] = useState<Challan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState("");
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => setSearch(searchInput.trim()), 300);
    return () => clearTimeout(t);
  }, [searchInput]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listChallans({ status, search });
        if (!active) return;
        setRows(data);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load challans.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [status, search, nonce]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={ClipboardList}
        tone="amber"
        title="Challans"
        subtitle="Delivery notes (quantities only). Stock leaves on creation; convert to an invoice to bill, or cancel to reverse."
      >
        <button
          type="button"
          onClick={() => setNonce((n) => n + 1)}
          disabled={loading}
          aria-label="Refresh"
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="invoices" label="Create challan">
          <Link
            href="/dashboard/challans/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> Create challan
          </Link>
        </MaybeLocked>
      </PageHeader>

      {/* Search */}
      <div className="mt-xl flex items-center gap-sm rounded-input border border-hairline bg-field px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
        <Search size={16} className="shrink-0 text-subtle" />
        <input
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          placeholder="Search challan no or party"
          className="h-10 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
        />
      </div>

      <div className="mt-md flex flex-wrap items-center gap-sm">
        {TABS.map((t) => (
          <button
            key={t.key}
            type="button"
            onClick={() => setStatus(t.key)}
            className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
              status === t.key ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-lg">
        {loading ? (
          <ListRowsSkeleton />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-accent-amber-soft text-accent-amber">
              <ClipboardList size={22} />
            </span>
            <p className="text-body-md text-muted">No challans found.</p>
            <MaybeLocked area="invoices" label="Create challan">
              <Link
                href="/dashboard/challans/new"
                className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
              >
                <Plus size={16} /> Create challan
              </Link>
            </MaybeLocked>
          </div>
        ) : (
          rows.map((c) => <ChallanRow key={c.id} challan={c} />)
        )}
      </div>
    </div>
  );
}

function ChallanRow({ challan }: { challan: Challan }) {
  const items = challanItemCount(challan);
  return (
    <Link
      href={`/dashboard/challans/${challan.id}`}
      className="flex items-center gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint"
    >
      <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-tint text-muted">
        <ClipboardList size={18} />
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-sm">
          <span className="truncate text-body-md text-ink">{challan.challanNo}</span>
          <span
            className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
              CHALLAN_STATUS_CLASSES[challan.status] ?? "bg-surface-tint text-muted"
            }`}
          >
            {CHALLAN_STATUS_LABELS[challan.status] ?? challan.status}
          </span>
        </div>
        <p className="truncate text-body-sm text-muted">{challan.partyName ?? "—"}</p>
        <p className="text-body-sm text-subtle">
          {formatDateTime(challan.createdAt)} · {items} {items === 1 ? "item" : "items"}
        </p>
      </div>
      <ChevronRight size={18} className="shrink-0 text-subtle" />
    </Link>
  );
}
