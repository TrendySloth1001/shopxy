"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { RotateCcw } from "@/shared/icons";
import { AppHeader } from "@/features/auth/components/app-header";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { fetchReturns } from "@/features/returns/api";
import { returnStatusVisual, type ReturnRequest } from "@/features/returns/types";
import { formatINR } from "@/shared/format";
import { formatDateTime } from "@/shared/datetime";
import { BackButton } from "@/shared/ui/back-button";

const PAGE_LIMIT = 20;

function ReturnRow({ item }: { item: ReturnRequest }) {
  const vis = returnStatusVisual(item.status);
  const itemCount = item.items.length;
  return (
    <Link
      href={`/returns/${item.id}`}
      className="block rounded-lg border border-hairline bg-white p-md hover:bg-surface-tint/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
    >
      <div className="flex items-start justify-between gap-sm">
        <p className="text-body-md font-extrabold text-ink line-clamp-1">
          Return #{item.id} · {item.shop.shopName ?? item.shop.name}
        </p>
        <span
          className={`inline-flex flex-shrink-0 rounded-full px-sm py-[3px] text-[11px] font-extrabold ${vis.colorClass} ${vis.bgClass}`}
        >
          {vis.label}
        </span>
      </div>
      <p className="mt-xs text-body-sm text-muted">
        {itemCount} {itemCount === 1 ? "item" : "items"} · {formatINR(item.refundAmount, { decimals: 2 })}
      </p>
      <p className="mt-[2px] text-label-sm text-muted">{formatDateTime(item.createdAt)}</p>
    </Link>
  );
}

function ReturnRowSkeleton() {
  return (
    <div className="animate-pulse rounded-lg border border-hairline bg-white p-md">
      <div className="flex items-center justify-between mb-xs">
        <div className="h-4 w-48 rounded bg-surface-tint" />
        <div className="h-5 w-20 rounded-full bg-surface-tint" />
      </div>
      <div className="h-3 w-32 rounded bg-surface-tint mb-xs" />
      <div className="h-3 w-24 rounded bg-surface-tint" />
    </div>
  );
}

function ReturnsContent() {
  const [returns, setReturns] = useState<ReturnRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError(null);
    try {
      const result = await fetchReturns({ page: p, limit: PAGE_LIMIT });
      setReturns(result.data);
      setTotal(result.pagination.total);
      setPage(p);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load returns.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function run() { await load(1); }
    if (!cancelled) void run();
    return () => { cancelled = true; };
  }, [load]);

  if (loading && returns.length === 0) {
    return (
      <div className="flex flex-col gap-sm px-lg py-sm">
        {Array.from({ length: 4 }).map((_, i) => <ReturnRowSkeleton key={i} />)}
      </div>
    );
  }

  if (error && returns.length === 0) {
    return (
      <div className="py-massive px-lg text-center">
        <p className="text-title-sm font-bold text-ink mb-xs">Something went wrong</p>
        <p className="text-body-sm text-muted mb-xl">{error}</p>
        <button
          onClick={() => void load(1)}
          className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
        >
          Try again
        </button>
      </div>
    );
  }

  if (returns.length === 0) {
    return (
      <div className="flex flex-col items-center py-massive px-lg text-center">
        <RotateCcw size={40} className="text-muted mb-md" />
        <p className="text-title-sm font-extrabold text-ink">No returns yet</p>
        <p className="mt-xs text-body-md text-muted">
          When you start a return from an order, it&apos;ll show up here.
        </p>
        <div className="mt-xl">
          <Link
            href="/orders"
            className="inline-flex h-10 items-center rounded-button border border-hairline px-xl text-label-md font-bold text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            View orders
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="px-lg py-sm">
      <div className="flex flex-col gap-sm pb-lg">
        {returns.map((r) => <ReturnRow key={r.id} item={r} />)}
      </div>

      {total > PAGE_LIMIT && (
        <div className="flex items-center justify-center gap-md py-md">
          <button
            onClick={() => void load(page - 1)}
            disabled={page <= 1 || loading}
            className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink disabled:opacity-40 hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            Previous
          </button>
          <span className="text-body-sm text-muted">
            Page {page} of {Math.ceil(total / PAGE_LIMIT)}
          </span>
          <button
            onClick={() => void load(page + 1)}
            disabled={page >= Math.ceil(total / PAGE_LIMIT) || loading}
            className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink disabled:opacity-40 hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}

export default function ReturnsPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <main className="min-h-screen bg-canvas">
        <div className="mx-auto max-w-shell px-lg pt-xl pb-sm">
          <BackButton fallback="/" className="mb-sm" />
          <h1 className="text-headline-sm font-extrabold text-ink">Returns</h1>
          <p className="mt-xs text-body-md text-muted">Your return requests and refund status.</p>
        </div>
        <div className="mx-auto max-w-shell">
          <ReturnsContent />
        </div>
      </main>
    </RequireAuth>
  );
}
