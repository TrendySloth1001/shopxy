"use client";

import { use, useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { ArrowLeft, X } from "@/shared/icons";
import { AppHeader } from "@/features/auth/components/app-header";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { ReturnTimeline } from "@/features/returns/components/return-timeline";
import { fetchReturnDetail, cancelReturn } from "@/features/returns/api";
import { returnStatusVisual, isReturnCancellable, reasonLabel, type ReturnRequest } from "@/features/returns/types";
import { formatINR } from "@/shared/format";
import { formatDateTime } from "@/shared/datetime";

// ─── Skeleton ────────────────────────────────────────────────────────────────

function ReturnDetailSkeleton() {
  return (
    <div className="animate-pulse px-md space-y-md py-md">
      {/* Hero card */}
      <div className="rounded-lg bg-white p-lg space-y-xs">
        <div className="h-4 w-36 rounded bg-surface-tint" />
        <div className="h-3 w-48 rounded bg-surface-tint" />
        <div className="mt-md h-3 w-16 rounded bg-surface-tint" />
        <div className="h-7 w-28 rounded bg-surface-tint" />
      </div>
      {/* Items card */}
      <div className="rounded-lg bg-white p-md space-y-md">
        {Array.from({ length: 2 }).map((_, i) => (
          <div key={i} className="flex gap-md">
            <div className="h-12 w-12 rounded-md bg-surface-tint flex-shrink-0" />
            <div className="flex-1 space-y-xs">
              <div className="h-4 w-40 rounded bg-surface-tint" />
              <div className="h-3 w-32 rounded bg-surface-tint" />
            </div>
            <div className="h-4 w-14 rounded bg-surface-tint" />
          </div>
        ))}
      </div>
      {/* Timeline card */}
      <div className="rounded-lg bg-white p-md space-y-sm">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="flex gap-md">
            <div className="h-5 w-5 rounded-full bg-surface-tint flex-shrink-0" />
            <div className="flex-1 space-y-xs">
              <div className="h-3 w-28 rounded bg-surface-tint" />
              <div className="h-3 w-20 rounded bg-surface-tint" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Detail content ────────────────────────────────────────────────────────

function ReturnDetailContent({ returnId }: { returnId: number }) {
  const [data, setData] = useState<ReturnRequest | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [cancelling, setCancelling] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [cancelSuccess, setCancelSuccess] = useState(false);
  const [showCancelDialog, setShowCancelDialog] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const r = await fetchReturnDetail(returnId);
      setData(r);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load return.");
    } finally {
      setLoading(false);
    }
  }, [returnId]);

  useEffect(() => {
    let cancelled = false;
    async function run() { await load(); }
    if (!cancelled) void run();
    return () => { cancelled = true; };
  }, [load]);

  async function doCancel() {
    setShowCancelDialog(false);
    if (cancelling) return;
    setCancelling(true);
    setCancelError(null);
    try {
      await cancelReturn(returnId);
      setCancelSuccess(true);
      await load();
    } catch (e) {
      setCancelError(e instanceof Error ? e.message : "Could not cancel return.");
    } finally {
      setCancelling(false);
    }
  }

  if (loading) return <ReturnDetailSkeleton />;

  if (error) {
    return (
      <div className="py-massive px-lg text-center">
        <p className="text-title-sm font-bold text-ink mb-xs">Something went wrong</p>
        <p className="text-body-sm text-muted mb-xl">{error}</p>
        <button
          onClick={() => void load()}
          className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
        >
          Try again
        </button>
      </div>
    );
  }

  if (!data) return null;

  const vis = returnStatusVisual(data.status);
  const canCancel = isReturnCancellable(data.status) && data.canCancel !== false;
  const isRefunded = data.status === "REFUNDED";

  return (
    <div className="px-md pb-huge space-y-md pt-md">
      {/* Cancel success toast */}
      {cancelSuccess && (
        <div className="rounded-md bg-success-soft p-md text-body-sm font-bold text-success">
          Return cancelled successfully.
        </div>
      )}

      {/* Hero card */}
      <div className="rounded-lg bg-white p-lg">
        <div className="flex items-start justify-between gap-sm">
          <div>
            <p className="text-body-md font-extrabold text-brand">
              {data.shop.shopName ?? data.shop.name}
            </p>
            <p className="mt-xs text-body-sm text-muted">{formatDateTime(data.createdAt)}</p>
          </div>
          <span
            className={`inline-flex flex-shrink-0 rounded-full px-sm py-[3px] text-caption font-extrabold ${vis.colorClass} ${vis.bgClass}`}
          >
            {vis.label}
          </span>
        </div>
        <div className="mt-md">
          <p className="text-caption font-extrabold tracking-[0.5px] text-muted uppercase">Refund</p>
          <p className="text-headline-sm font-extrabold text-ink">
            {formatINR(data.refundAmount, { decimals: 2 })}
          </p>
          {isRefunded && (
            <p className="mt-xs text-body-sm font-bold text-success">
              Refunded to your original payment method
            </p>
          )}
        </div>
      </div>

      {/* Items */}
      <div className="rounded-lg bg-white overflow-hidden">
        {data.items.map((item, idx) => {
          const img = item.purchaseRequestItem.product?.images?.[0]?.url;
          const imgSrc = img ? `/api/media/${img.replace(/^\//, "")}` : null;
          const qty = item.quantity;
          const qtyStr = Number.isInteger(qty) ? String(qty) : qty.toFixed(2);
          return (
            <div key={item.id}>
              {idx > 0 && <div className="h-px bg-hairline mx-md" />}
              <div className="flex items-start gap-md p-md">
                <div className="h-12 w-12 flex-shrink-0 rounded-md bg-hero-panel overflow-hidden">
                  {imgSrc ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={imgSrc}
                      alt={item.purchaseRequestItem.productName}
                      className="h-full w-full object-cover"
                    />
                  ) : null}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-body-sm font-bold text-ink line-clamp-2">
                    {item.purchaseRequestItem.productName}
                  </p>
                  <p className="mt-xs text-caption text-muted">
                    {qtyStr} {item.purchaseRequestItem.unit} · {reasonLabel(item.reason)}
                  </p>
                </div>
                <span className="text-body-sm font-extrabold text-ink flex-shrink-0">
                  {formatINR(item.refundAmount, { decimals: 2 })}
                </span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Timeline */}
      <div className="rounded-lg bg-white p-md pb-sm">
        <ReturnTimeline events={data.events} status={data.status} />
      </div>

      {/* Customer note */}
      {data.note && (
        <div className="rounded-lg bg-surface-tint p-md">
          <p className="text-caption font-extrabold tracking-[0.5px] text-muted/70 uppercase mb-xs">
            Your note
          </p>
          <p className="text-body-md text-ink">{data.note}</p>
        </div>
      )}

      {/* Seller decision note */}
      {data.decisionNote && (
        <div className={`rounded-lg p-md ${data.status === "REJECTED" ? "bg-error-soft" : "bg-surface-tint"}`}>
          <p
            className={`text-caption font-extrabold tracking-[0.5px] uppercase mb-xs ${data.status === "REJECTED" ? "text-error/70" : "text-muted/70"}`}
          >
            Seller&apos;s note
          </p>
          <p className={`text-body-md ${data.status === "REJECTED" ? "text-error" : "text-ink"}`}>
            {data.decisionNote}
          </p>
        </div>
      )}

      {/* Cancel button */}
      {canCancel && (
        <div>
          {cancelError && (
            <p className="mb-sm text-body-sm font-bold text-error">{cancelError}</p>
          )}
          <button
            onClick={() => setShowCancelDialog(true)}
            disabled={cancelling}
            className="flex w-full items-center justify-center gap-sm rounded-lg border border-error-soft py-lg text-body-md font-extrabold text-error disabled:opacity-60 hover:bg-error-soft/30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error transition-colors"
          >
            {cancelling ? (
              <span className="h-4 w-4 rounded-full border-2 border-error/30 border-t-error animate-spin" />
            ) : (
              <X size={16} />
            )}
            Cancel return
          </button>
        </div>
      )}

      {/* Cancel confirm dialog */}
      {showCancelDialog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 px-lg">
          <div className="w-full max-w-narrow rounded-dialog bg-white p-xl">
            <h2 className="text-title-md font-extrabold text-ink">Cancel this return?</h2>
            <p className="mt-sm text-body-sm text-muted">
              You&apos;ll need to start a new return if you change your mind.
            </p>
            <div className="mt-xl flex gap-sm">
              <button
                onClick={() => setShowCancelDialog(false)}
                className="inline-flex h-10 flex-1 items-center justify-center rounded-button border border-hairline bg-white text-label-md text-ink hover:bg-canvas focus-visible:outline-none"
              >
                Keep return
              </button>
              <button
                onClick={() => void doCancel()}
                className="inline-flex h-10 flex-1 items-center justify-center rounded-button bg-error text-label-md font-bold text-white hover:opacity-90 focus-visible:outline-none"
              >
                Cancel return
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function ReturnDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const returnId = parseInt(id, 10);

  return (
    <RequireAuth>
      <AppHeader />
      <main className="min-h-screen bg-canvas">
        <div className="mx-auto max-w-shell px-lg pt-md pb-xs flex items-center gap-sm">
          <Link
            href="/returns"
            className="flex h-8 w-8 items-center justify-center rounded-full text-muted hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
          >
            <ArrowLeft size={16} />
          </Link>
          <h1 className="text-title-md font-extrabold text-ink">Return #{returnId}</h1>
        </div>
        <div className="mx-auto max-w-shell">
          <ReturnDetailContent returnId={returnId} />
        </div>
      </main>
    </RequireAuth>
  );
}
