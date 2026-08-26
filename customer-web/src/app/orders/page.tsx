"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { ShoppingBag } from "@/shared/icons";
import { AppHeader } from "@/features/auth/components/app-header";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { OrderCard } from "@/features/orders/components/order-card";
import { OrderListSkeleton } from "@/features/orders/components/order-skeleton";
import { fetchOrders } from "@/features/orders/api";
import { BackButton } from "@/shared/ui/back-button";
import {
  isChildPending,
  isChildConfirmed,
  isChildRejected,
  isChildCancelled,
  type CustomerOrder,
} from "@/features/orders/types";

type OrderFilter = "all" | "pending" | "confirmed" | "cancelled" | "declined";

const FILTERS: { key: OrderFilter; label: string }[] = [
  { key: "all", label: "All" },
  { key: "pending", label: "Pending" },
  { key: "confirmed", label: "Confirmed" },
  { key: "cancelled", label: "Cancelled" },
  { key: "declined", label: "Declined" },
];

function filterBucket(order: CustomerOrder): Exclude<OrderFilter, "all"> {
  const c = order.shopOrders;
  if (c.length === 0) return "pending";
  const pending = c.filter(isChildPending).length;
  const confirmed = c.filter(isChildConfirmed).length;
  const rejected = c.filter(isChildRejected).length;
  const cancelled = c.filter(isChildCancelled).length;
  if (pending > 0) return "pending";
  if (confirmed > 0) return "confirmed";
  if (rejected >= cancelled) return "declined";
  return "cancelled";
}

function emptyLine(filter: OrderFilter): string {
  switch (filter) {
    case "all": return "You haven't placed any orders yet";
    case "pending": return "No orders waiting on a seller";
    case "confirmed": return "No confirmed orders yet";
    case "cancelled": return "No cancelled orders";
    case "declined": return "No declined orders";
  }
}

const PAGE_LIMIT = 20;

function OrdersContent() {
  const [orders, setOrders] = useState<CustomerOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [filter, setFilter] = useState<OrderFilter>("all");

  const load = useCallback(async (p = 1) => {
    setLoading(true);
    setError(null);
    try {
      const result = await fetchOrders({ page: p, limit: PAGE_LIMIT });
      setOrders(result.data);
      setTotal(result.pagination.total);
      setPage(p);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load orders.");
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

  const counts: Partial<Record<OrderFilter, number>> = { all: orders.length };
  for (const o of orders) {
    const bucket = filterBucket(o);
    counts[bucket] = (counts[bucket] ?? 0) + 1;
  }

  const visible =
    filter === "all" ? orders : orders.filter((o) => filterBucket(o) === filter);

  const visibleFilters = FILTERS.filter(
    (f) => f.key === "all" || (counts[f.key] ?? 0) > 0 || filter === f.key,
  );

  if (loading && orders.length === 0) {
    return (
      <div className="mx-auto max-w-shell px-lg py-md">
        <OrderListSkeleton />
      </div>
    );
  }

  if (error && orders.length === 0) {
    return (
      <div className="mx-auto max-w-shell px-lg py-massive text-center">
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

  if (orders.length === 0) {
    return (
      <div className="mx-auto max-w-shell px-lg py-massive text-center">
        <div className="mx-auto mb-lg flex h-24 w-24 items-center justify-center rounded-xl bg-hero-panel">
          <ShoppingBag size={40} className="text-muted" />
        </div>
        <p className="text-title-md font-extrabold text-ink">No orders yet</p>
        <p className="mt-xs text-body-md text-muted">
          Your purchases, tracking and invoices will appear here.
        </p>
        <div className="mt-xl">
          <Link
            href="/"
            className="inline-flex h-10 items-center rounded-button bg-ink px-xl text-label-md font-bold text-white hover:bg-ink/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            Browse products
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-shell">
      <div className="sticky top-0 z-10 border-b border-hairline bg-canvas">
        <div className="flex gap-sm overflow-x-auto px-lg py-sm scrollbar-hide">
          {visibleFilters.map((f) => (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={`inline-flex flex-shrink-0 items-center gap-sm rounded-full px-md py-sm text-label-md font-extrabold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
                filter === f.key
                  ? "bg-ink text-white"
                  : "border border-hairline bg-white text-ink hover:bg-surface-tint"
              }`}
            >
              {f.label}
              <span
                className={`text-caption font-bold ${filter === f.key ? "text-white/70" : "text-muted"}`}
              >
                {counts[f.key] ?? 0}
              </span>
            </button>
          ))}
        </div>
      </div>

      <div className="px-lg py-sm">
        {visible.length === 0 ? (
          <div className="py-massive text-center">
            <p className="text-body-md font-semibold text-muted">{emptyLine(filter)}</p>
          </div>
        ) : (
          <div className="flex flex-col gap-sm pb-lg">
            {visible.map((order) => (
              <OrderCard key={order.id} order={order} />
            ))}
          </div>
        )}

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
    </div>
  );
}

export default function OrdersPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <main className="min-h-screen bg-canvas">
        <div className="mx-auto max-w-shell px-lg pt-xl pb-sm">
          <BackButton fallback="/" className="mb-sm" />
          <h1 className="text-headline-sm font-extrabold text-ink">My Orders</h1>
        </div>
        <OrdersContent />
      </main>
    </RequireAuth>
  );
}
