"use client";

import { useEffect, useState, useCallback, startTransition } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { ChevronRight, ArrowDownLeft, ArrowUpRight } from "@/shared/icons";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { fetchInvoices } from "@/features/merchant-ledger/api";
import {
  PageError,
  InvoiceEmptyState,
  InvoiceStatusBadge,
  SkeletonLine,
  SkeletonBlock,
} from "@/features/merchant-ledger/components/shared";
import type { InvoiceListItem, MerchantRole } from "@/features/merchant-ledger/types";
import { formatINR } from "@/shared/format";
import { formatDate } from "@/shared/datetime";
import { BackButton } from "@/shared/ui/back-button";

function InvoiceRowSkeleton() {
  return (
    <div className="flex items-center gap-md px-lg py-md">
      <SkeletonBlock className="h-10 w-10 shrink-0 rounded-md" />
      <div className="flex flex-1 flex-col gap-xs">
        <SkeletonLine className="h-4 w-[55%]" />
        <SkeletonLine className="h-3 w-[75%]" />
      </div>
      <SkeletonLine className="h-4 w-16" />
    </div>
  );
}

function InvoiceRow({
  invoice,
  href,
}: {
  invoice: InvoiceListItem;
  href: string;
}) {
  const isSale = invoice.type === "SALE" || invoice.type === "SALES";
  return (
    <Link href={href} className="group flex items-center gap-md px-lg py-md hover:bg-surface-tint transition-colors">
      <span
        className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-md ${
          isSale ? "bg-accent-indigo-soft" : "bg-success-soft"
        }`}
      >
        {isSale ? (
          <ArrowDownLeft size={18} className="text-accent-indigo" />
        ) : (
          <ArrowUpRight size={18} className="text-success" />
        )}
      </span>
      <div className="flex flex-1 flex-col gap-xxs min-w-0">
        <span className="text-body-md font-extrabold text-ink truncate">{invoice.invoiceNo}</span>
        <span className="text-body-sm text-muted">
          {formatDate(invoice.invoiceDate)} · {invoice._count?.items ?? 0} items
        </span>
      </div>
      <div className="flex flex-col items-end gap-xs shrink-0">
        <span className="text-body-md font-extrabold text-ink tabular-nums">
          {formatINR(invoice.total)}
        </span>
        {invoice.status && <InvoiceStatusBadge status={invoice.status} />}
      </div>
      <ChevronRight size={18} className="text-muted group-hover:text-ink transition-colors shrink-0" />
    </Link>
  );
}

function InvoicesPageContent() {
  const params = useParams<{ role: string; id: string }>();
  const role = params.role as MerchantRole;
  const id = params.id;
  const router = useRouter();

  const [invoices, setInvoices] = useState<InvoiceListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const limit = 30;

  const load = useCallback(
    async (p: number) => {
      if (role !== "party" && role !== "vendor") {
        router.replace("/merchants");
        return;
      }
      setLoading(true);
      setError(null);
      try {
        const data = await fetchInvoices(role, id, { page: p, limit });
        setInvoices(data.data);
        setTotal(data.pagination.total);
        setPage(p);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Could not load invoices.");
      } finally {
        setLoading(false);
      }
    },
    [role, id, router],
  );

  useEffect(() => {
    startTransition(() => { void load(1); });
  }, [load]);

  const totalPages = Math.ceil(total / limit);

  return (
    <div className="mx-auto max-w-shell px-0 sm:px-lg py-xxxl">
      <div className="mx-auto max-w-content">
        {/* Header */}
        <div className="px-lg sm:px-0 mb-xxl">
          <BackButton fallback="/merchants" className="mb-sm" />
          <h1 className="text-headline-sm font-extrabold text-ink">Invoices</h1>
          {total > 0 && !loading && (
            <p className="text-body-sm text-muted mt-xs">{total} invoice{total !== 1 ? "s" : ""}</p>
          )}
        </div>

        {/* Loading skeletons */}
        {loading && invoices.length === 0 && (
          <div className="divide-y divide-hairline">
            {Array.from({ length: 8 }).map((_, i) => (
              <InvoiceRowSkeleton key={i} />
            ))}
          </div>
        )}

        {/* Error */}
        {!loading && error && invoices.length === 0 && (
          <PageError message={error} onRetry={() => load(1)} />
        )}

        {/* Empty */}
        {!loading && !error && invoices.length === 0 && <InvoiceEmptyState />}

        {/* List */}
        {invoices.length > 0 && (
          <>
            <div className="divide-y divide-hairline border-y border-hairline">
              {invoices.map((inv) => (
                <InvoiceRow
                  key={inv.id}
                  invoice={inv}
                  href={`/merchants/${role}/${id}/invoices/${inv.id}`}
                />
              ))}
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-center gap-md mt-xxl px-lg">
                <button
                  disabled={page <= 1 || loading}
                  onClick={() => load(page - 1)}
                  className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink disabled:text-disabled hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                >
                  Previous
                </button>
                <span className="text-body-sm text-muted">
                  {page} of {totalPages}
                </span>
                <button
                  disabled={page >= totalPages || loading}
                  onClick={() => load(page + 1)}
                  className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink disabled:text-disabled hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
                >
                  Next
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

export default function InvoicesPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <InvoicesPageContent />
    </RequireAuth>
  );
}
