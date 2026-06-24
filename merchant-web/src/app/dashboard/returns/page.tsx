"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ChevronRight, RefreshCw, Undo2 } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { formatDateTime } from "@/shared/datetime";
import { formatINR } from "@/shared/money";
import { listReturns } from "@/features/returns/api";
import {
  RETURN_STATUS_CLASSES,
  RETURN_STATUS_LABELS,
  customerName,
  type MerchantReturn,
} from "@/features/returns/schema";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

const TABS: { key: string; label: string }[] = [
  { key: "REQUESTED", label: "Open" },
  { key: "APPROVED", label: "Approved" },
  { key: "RECEIVED", label: "Received" },
  { key: "REFUNDED", label: "Refunded" },
  { key: "", label: "All" },
];

export default function ReturnsPage() {
  const [rows, setRows] = useState<MerchantReturn[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState("REQUESTED");
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listReturns(status ? { status } : undefined);
        if (!active) return;
        setRows(data);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load returns.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [status, nonce]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Undo2}
        tone="amber"
        title="Returns"
        subtitle="Customer return requests. Approve or reject, mark picked-up and received, then refund — the buyer's original payment method is credited and stock restocked."
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
      </PageHeader>

      <div className="mt-xl flex flex-wrap items-center gap-sm">
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
              <Undo2 size={22} />
            </span>
            <p className="text-body-md text-muted">No returns in this view.</p>
            <Link
              href="/dashboard/orders"
              className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              View orders
            </Link>
          </div>
        ) : (
          rows.map((r) => <ReturnRow key={r.id} ret={r} />)
        )}
      </div>
    </div>
  );
}

function ReturnRow({ ret }: { ret: MerchantReturn }) {
  const items = ret.items.length;
  const products = ret.items
    .map((it) => it.purchaseRequestItem?.productName)
    .filter(Boolean)
    .slice(0, 2)
    .join(", ");
  return (
    <Link
      href={`/dashboard/returns/${ret.id}`}
      className="flex items-center gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint"
    >
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-sm">
          <span className="truncate text-body-md text-ink">{customerName(ret)}</span>
          <span
            className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
              RETURN_STATUS_CLASSES[ret.status] ?? "bg-surface-tint text-muted"
            }`}
          >
            {RETURN_STATUS_LABELS[ret.status] ?? ret.status}
          </span>
        </div>
        {products ? <p className="truncate text-body-sm text-muted">{products}</p> : null}
        <p className="text-body-sm text-subtle">
          {formatDateTime(ret.createdAt)} · {items} {items === 1 ? "item" : "items"}
        </p>
      </div>
      <span className="shrink-0 text-body-md font-semibold text-ink">{formatINR(ret.refundAmount)}</span>
      <ChevronRight size={18} className="shrink-0 text-subtle" />
    </Link>
  );
}
