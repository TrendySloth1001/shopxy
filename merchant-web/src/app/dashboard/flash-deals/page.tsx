"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Plus, RefreshCw, StopCircle, Zap } from "lucide-react";
import { ProductThumb } from "@/features/products/components/product-thumb";
import { PageHeader } from "@/shared/ui/page-header";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { formatDateRange } from "@/shared/datetime";
import { cancelFlashDeal, listFlashDeals } from "@/features/flash-deals/api";
import { discountPct, flashBucket, money, soldPct } from "@/features/flash-deals/format";
import {
  FLASH_STATUSES,
  FLASH_STATUS_LABELS,
  type FlashSale,
  type FlashStatus,
} from "@/features/flash-deals/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function FlashDealsPage() {
  const [deals, setDeals] = useState<FlashSale[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [tab, setTab] = useState<FlashStatus>("active");
  const [cancelTarget, setCancelTarget] = useState<FlashSale | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const rows = await listFlashDeals();
        if (!active) return;
        setDeals(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load flash deals.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  const buckets = useMemo(() => {
    const out: Record<FlashStatus, FlashSale[]> = { active: [], scheduled: [], past: [] };
    for (const d of deals) out[flashBucket(d)].push(d);
    return out;
  }, [deals]);

  async function confirmCancel() {
    if (!cancelTarget) return;
    setCancelBusy(true);
    try {
      await cancelFlashDeal(cancelTarget.id);
      setCancelTarget(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not cancel the flash deal.");
    } finally {
      setCancelBusy(false);
    }
  }

  const rows = buckets[tab];

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Zap}
        tone="flash"
        title="Flash deals"
        subtitle="Time-boxed discounts with a hard stock cap — they surface on your storefront while live."
      >
        <button
          type="button"
          onClick={reload}
          disabled={loading}
          aria-label="Refresh"
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="marketing" label="New flash deal">
          <Link
            href="/dashboard/flash-deals/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> New flash deal
          </Link>
        </MaybeLocked>
      </PageHeader>

      {/* Tabs */}
      <div className="mt-xl flex gap-xs border-b border-hairline">
        {FLASH_STATUSES.map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setTab(s)}
            className={`-mb-px border-b-2 px-md py-sm text-label-md transition-colors ${
              tab === s
                ? "border-brand text-brand-strong"
                : "border-transparent text-muted hover:text-ink"
            }`}
          >
            {FLASH_STATUS_LABELS[s]} <span className="text-subtle">({buckets[s].length})</span>
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
          <EmptyState tab={tab} />
        ) : (
          rows.map((deal) => (
            <DealRow key={deal.id} deal={deal} tab={tab} onCancel={() => setCancelTarget(deal)} />
          ))
        )}
      </div>

      {cancelTarget ? (
        <Modal title="Cancel flash deal?" onClose={() => setCancelTarget(null)}>
          <p className="text-body-md text-muted">
            Stops accepting new buyers at the discounted price for{" "}
            <span className="text-ink">{cancelTarget.product?.name ?? `#${cancelTarget.productId}`}</span>.
            Already-claimed units stay claimed.
          </p>
          <ModalActions
            busy={cancelBusy}
            danger
            confirmLabel="Cancel sale"
            onCancel={() => setCancelTarget(null)}
            onConfirm={confirmCancel}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function EmptyState({ tab }: { tab: FlashStatus }) {
  const copy =
    tab === "active"
      ? "No live flash deals right now."
      : tab === "scheduled"
        ? "Nothing scheduled."
        : "No past flash deals yet.";
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-12 items-center justify-center rounded-full bg-flash-deal-soft text-flash-deal">
        <Zap size={22} />
      </span>
      <p className="text-body-md text-muted">{copy}</p>
      {tab === "active" ? (
        <MaybeLocked area="marketing" label="New flash deal">
          <Link
            href="/dashboard/flash-deals/new"
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Plus size={16} /> New flash deal
          </Link>
        </MaybeLocked>
      ) : null}
    </div>
  );
}

function DealRow({ deal, tab, onCancel }: { deal: FlashSale; tab: FlashStatus; onCancel: () => void }) {
  const pct = soldPct(deal);
  const off = deal.product ? discountPct(deal.product.mrp, deal.flashPrice) : 0;
  return (
    <div className="flex flex-col gap-sm border-b border-hairline py-md">
      <div className="flex items-start gap-md">
        <Link href={`/dashboard/flash-deals/${deal.id}`} className="flex min-w-0 flex-1 items-start gap-md">
          <ProductThumb url={deal.product?.images[0]?.url} alt={deal.product?.name ?? "Product"} size={52} />
          <span className="min-w-0 flex-1">
            <span className="block truncate text-body-md text-ink">
              {deal.product?.name ?? `Product #${deal.productId}`}
            </span>
            <span className="mt-px flex flex-wrap items-baseline gap-sm">
              <span className="text-title-sm font-bold text-flash-deal">{money(deal.flashPrice)}</span>
              {deal.product && deal.product.mrp > 0 ? (
                <span className="text-body-sm text-muted line-through">{money(deal.product.mrp)}</span>
              ) : null}
              {off > 0 ? <span className="text-body-sm font-semibold text-flash-deal">{off}% off</span> : null}
            </span>
          </span>
        </Link>
        {tab !== "past" ? (
          <button
            type="button"
            onClick={onCancel}
            aria-label="Cancel sale"
            className="inline-flex size-9 shrink-0 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error"
          >
            <StopCircle size={18} />
          </button>
        ) : null}
      </div>

      <div>
        <div className="h-2 w-full overflow-hidden rounded-full bg-flash-deal-soft">
          <div className="h-full rounded-full bg-flash-deal" style={{ width: `${pct * 100}%` }} />
        </div>
        <p className="mt-xs text-body-sm font-semibold text-flash-deal">
          {deal.soldCount} / {deal.stockLimit} claimed · {Math.round(pct * 100)}%
        </p>
      </div>

      <p className="text-body-sm text-muted">{formatDateRange(deal.startAt, deal.endAt)}</p>
    </div>
  );
}
