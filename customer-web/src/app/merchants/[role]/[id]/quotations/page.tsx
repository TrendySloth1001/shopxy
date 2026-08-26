"use client";

import { useEffect, useState, useCallback, startTransition } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { ChevronRight, Plus } from "@/shared/icons";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { fetchQuotations } from "@/features/merchant-ledger/api";
import {
  QuotationStatusBadge,
  QuotationEmptyState,
  PageError,
  SkeletonLine,
  SkeletonBlock,
} from "@/features/merchant-ledger/components/shared";
import type { Quotation } from "@/features/merchant-ledger/types";
import { formatINR } from "@/shared/format";
import { formatDate } from "@/shared/datetime";
import { BackButton } from "@/shared/ui/back-button";

function QuotationRowSkeleton() {
  return (
    <div className="flex items-center gap-md px-lg py-md">
      <div className="flex-1 space-y-xs">
        <div className="flex gap-sm items-center">
          <SkeletonBlock className="h-5 w-20 rounded-sm" />
          <SkeletonBlock className="h-5 w-16 rounded-full" />
        </div>
        <SkeletonLine className="h-3 w-[65%]" />
      </div>
      <SkeletonLine className="h-4 w-16" />
      <SkeletonBlock className="h-5 w-5 rounded-sm" />
    </div>
  );
}

function QuotationRow({ q, href }: { q: Quotation; href: string }) {
  const isQuoted = q.status === "QUOTED";
  return (
    <Link href={href} className="group flex items-center gap-md px-lg py-md hover:bg-surface-tint transition-colors">
      <div className="flex-1 min-w-0">
        <div className="flex flex-wrap items-center gap-xs mb-xxs">
          <span className="text-body-md font-extrabold text-ink">{q.quotationNo}</span>
          <QuotationStatusBadge status={q.status} />
        </div>
        <p className="text-body-sm text-muted">
          {formatDate(q.createdAt)} · {q.items.length} item{q.items.length !== 1 ? "s" : ""}
        </p>
      </div>
      <span className="text-body-md font-extrabold text-ink tabular-nums shrink-0">
        {formatINR(q.total)}
      </span>
      {isQuoted ? (
        <span className="inline-flex h-8 shrink-0 items-center rounded-button border border-brand px-md text-label-md font-bold text-brand group-hover:bg-brand-soft transition-colors">
          Review
        </span>
      ) : (
        <ChevronRight size={18} className="text-muted group-hover:text-ink transition-colors shrink-0" />
      )}
    </Link>
  );
}

function QuotationsPageContent() {
  const params = useParams<{ role: string; id: string }>();
  const role = params.role;
  const id = params.id;
  const router = useRouter();

  const [quotations, setQuotations] = useState<Quotation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const limit = 30;

  useEffect(() => {
    if (role !== "party") {
      router.replace(`/merchants/${role}/${id}/invoices`);
    }
  }, [role, id, router]);

  const load = useCallback(
    async (p: number) => {
      setLoading(true);
      setError(null);
      try {
        const data = await fetchQuotations(id, { page: p, limit });
        setQuotations(data.data);
        setTotal(data.pagination.total);
        setPage(p);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Could not load quotations.");
      } finally {
        setLoading(false);
      }
    },
    [id],
  );

  useEffect(() => {
    startTransition(() => { void load(1); });
  }, [load]);

  const totalPages = Math.ceil(total / limit);

  return (
    <div className="mx-auto max-w-shell px-0 sm:px-lg py-xxxl">
      <div className="mx-auto max-w-content">
        <div className="px-lg sm:px-0 mb-xxl">
          <BackButton fallback="/merchants" className="mb-sm" />
          <div className="flex items-start justify-between gap-md">
            <div>
              <h1 className="text-headline-sm font-extrabold text-ink">Quotations</h1>
              {total > 0 && !loading && (
                <p className="text-body-sm text-muted mt-xs">
                  {total} quotation{total !== 1 ? "s" : ""}
                </p>
              )}
            </div>
            <Link
              href={`/merchants/${role}/${id}/request-quote`}
              className="inline-flex h-10 shrink-0 items-center gap-xs rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
            >
              <Plus size={16} />
              Request quote
            </Link>
          </div>
        </div>

        {loading && quotations.length === 0 && (
          <div className="divide-y divide-hairline">
            {Array.from({ length: 7 }).map((_, i) => (
              <QuotationRowSkeleton key={i} />
            ))}
          </div>
        )}

        {!loading && error && quotations.length === 0 && (
          <PageError message={error} onRetry={() => load(1)} />
        )}

        {!loading && !error && quotations.length === 0 && (
          <QuotationEmptyState
            onRequest={() => router.push(`/merchants/${role}/${id}/request-quote`)}
          />
        )}

        {quotations.length > 0 && (
          <>
            <div className="divide-y divide-hairline border-y border-hairline">
              {quotations.map((q) => (
                <QuotationRow
                  key={q.id}
                  q={q}
                  href={`/merchants/${role}/${id}/quotations/${q.id}`}
                />
              ))}
            </div>

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

export default function QuotationsPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <QuotationsPageContent />
    </RequireAuth>
  );
}
