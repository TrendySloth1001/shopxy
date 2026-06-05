"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { BarChart3, Plus, RefreshCw, StopCircle, Zap } from "lucide-react";
import { ProductThumb } from "@/features/products/components/product-thumb";
import {
  ProductPicker,
  type PickedProduct,
} from "@/features/products/components/product-picker";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { DateTimeField, TextField } from "@/shared/ui/form";
import { formatDateRange, formatDateTime, isoFromNow, nowIso } from "@/shared/datetime";
import {
  cancelFlashDeal,
  createFlashDeal,
  getFlashDealAnalytics,
  updateFlashDeal,
  listFlashDeals,
} from "@/features/flash-deals/api";
import { discountPct, flashBucket, money, soldPct } from "@/features/flash-deals/format";
import {
  FLASH_STATUSES,
  FLASH_STATUS_LABELS,
  type FlashAnalytics,
  type FlashSale,
  type FlashStatus,
} from "@/features/flash-deals/schema";

export default function FlashDealsPage() {
  const [deals, setDeals] = useState<FlashSale[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [tab, setTab] = useState<FlashStatus>("active");
  const [editing, setEditing] = useState<FlashSale | "new" | null>(null);
  const [cancelTarget, setCancelTarget] = useState<FlashSale | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [analyticsTarget, setAnalyticsTarget] = useState<FlashSale | null>(null);

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
      <div className="flex flex-wrap items-start justify-between gap-md">
        <div>
          <div className="flex items-center gap-sm">
            <Zap size={22} className="text-flash-deal" />
            <h1 className="text-headline-md text-ink">Flash deals</h1>
          </div>
          <p className="mt-xs text-body-md text-muted">
            Time-boxed discounts with a hard stock cap — they surface on your storefront while live.
          </p>
        </div>
        <div className="flex items-center gap-sm">
          <button
            type="button"
            onClick={reload}
            disabled={loading}
            aria-label="Refresh"
            className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            <RefreshCw size={16} />
          </button>
          <button
            type="button"
            onClick={() => setEditing("new")}
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> New flash deal
          </button>
        </div>
      </div>

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
            {FLASH_STATUS_LABELS[s]}{" "}
            <span className="text-subtle">({buckets[s].length})</span>
          </button>
        ))}
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {/* List */}
      <div className="mt-lg">
        {loading ? (
          <p className="py-xxl text-center text-body-sm text-subtle">Loading…</p>
        ) : rows.length === 0 ? (
          <EmptyState tab={tab} onNew={() => setEditing("new")} />
        ) : (
          rows.map((deal) => (
            <DealRow
              key={deal.id}
              deal={deal}
              tab={tab}
              onEdit={() => setEditing(deal)}
              onCancel={() => setCancelTarget(deal)}
              onAnalytics={() => setAnalyticsTarget(deal)}
            />
          ))
        )}
      </div>

      {editing ? (
        <FlashDealEditor
          existing={editing === "new" ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            reload();
          }}
        />
      ) : null}

      {analyticsTarget ? (
        <FlashAnalyticsModal deal={analyticsTarget} onClose={() => setAnalyticsTarget(null)} />
      ) : null}

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

function EmptyState({ tab, onNew }: { tab: FlashStatus; onNew: () => void }) {
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
        <button
          type="button"
          onClick={onNew}
          className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
        >
          <Plus size={16} /> New flash deal
        </button>
      ) : null}
    </div>
  );
}

function DealRow({
  deal,
  tab,
  onEdit,
  onCancel,
  onAnalytics,
}: {
  deal: FlashSale;
  tab: FlashStatus;
  onEdit: () => void;
  onCancel: () => void;
  onAnalytics: () => void;
}) {
  const pct = soldPct(deal);
  const off = deal.product ? discountPct(deal.product.mrp, deal.flashPrice) : 0;
  return (
    <div className="flex flex-col gap-sm border-b border-hairline py-md">
      <div className="flex items-start gap-md">
        <button type="button" onClick={onEdit} className="flex min-w-0 flex-1 items-start gap-md text-left">
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
        </button>
        <button
          type="button"
          onClick={onAnalytics}
          aria-label="Analytics"
          className="inline-flex size-9 shrink-0 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
        >
          <BarChart3 size={18} />
        </button>
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

// ── Editor ────────────────────────────────────────────────────────────

function FlashDealEditor({
  existing,
  onClose,
  onSaved,
}: {
  existing: FlashSale | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const isEdit = existing != null;
  const [picked, setPicked] = useState<PickedProduct | null>(
    existing?.product
      ? {
          id: existing.product.id,
          name: existing.product.name,
          sku: existing.product.sku ?? "",
          mrp: existing.product.mrp,
          sellingPrice: existing.product.sellingPrice,
          imageUrl: existing.product.images[0]?.url ?? null,
        }
      : null,
  );
  const [pickerOpen, setPickerOpen] = useState(false);
  const [flashPrice, setFlashPrice] = useState(existing ? String(existing.flashPrice) : "");
  const [stockLimit, setStockLimit] = useState(existing ? String(existing.stockLimit) : "50");
  const [startAt, setStartAt] = useState<string | null>(existing?.startAt ?? nowIso());
  const [endAt, setEndAt] = useState<string | null>(
    existing?.endAt ?? isoFromNow(4 * 60 * 60 * 1000),
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const priceNum = Number(flashPrice);
  const stockNum = Number(stockLimit);
  const mrp = picked?.mrp ?? 0;
  const off = picked ? discountPct(mrp, priceNum || 0) : 0;
  const priceError =
    flashPrice && mrp > 0 && priceNum >= mrp ? `Must be below MRP (${money(mrp)})` : null;

  function onPickProduct(p: PickedProduct) {
    setPicked(p);
    setPickerOpen(false);
    if (!flashPrice && p.sellingPrice > 0) {
      setFlashPrice((p.sellingPrice * 0.8).toFixed(2));
    }
  }

  async function save() {
    setError(null);
    if (!isEdit && !picked) return setError("Pick a product first.");
    if (!flashPrice || Number.isNaN(priceNum) || priceNum < 0) {
      return setError("Enter a valid flash price.");
    }
    if (mrp > 0 && priceNum >= mrp) return setError("Flash price must be below MRP.");
    if (!stockLimit || !Number.isInteger(stockNum) || stockNum <= 0) {
      return setError("Enter a positive stock cap.");
    }
    if (!startAt || !endAt || new Date(endAt) <= new Date(startAt)) {
      return setError("End time must be after the start time.");
    }
    setBusy(true);
    try {
      if (isEdit) {
        await updateFlashDeal(existing.id, {
          flashPrice: priceNum,
          stockLimit: stockNum,
          startAt,
          endAt,
        });
      } else {
        await createFlashDeal({
          productId: picked!.id,
          flashPrice: priceNum,
          stockLimit: stockNum,
          startAt,
          endAt,
        });
      }
      onSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Save failed.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title={isEdit ? "Edit flash deal" : "New flash deal"} onClose={onClose} wide>
      {/* Preview */}
      <div className="flex items-center gap-md rounded-lg bg-gradient-to-br from-flash-deal-soft to-flash-deal-soft-alt p-md">
        <div className="relative shrink-0">
          <ProductThumb url={picked?.imageUrl} alt={picked?.name ?? "Product"} size={72} />
          {off > 0 ? (
            <span className="absolute left-0 top-0 rounded-br-md rounded-tl-md bg-flash-deal px-xs py-px text-body-sm font-bold text-white">
              -{off}%
            </span>
          ) : null}
        </div>
        <div className="min-w-0 flex-1">
          <span className="flex items-center gap-xs text-body-sm font-semibold text-flash-deal">
            <Zap size={14} /> Flash deal preview
          </span>
          <p className="mt-px truncate text-body-md font-semibold text-ink">
            {picked?.name ?? "Pick a product to preview"}
          </p>
          <p className="mt-xs flex items-baseline gap-sm">
            <span className="text-title-sm font-bold text-flash-deal">
              {money(Number.isFinite(priceNum) ? priceNum : 0)}
            </span>
            {picked && mrp > 0 ? (
              <span className="text-body-sm text-muted line-through">{money(mrp)}</span>
            ) : null}
          </p>
        </div>
      </div>

      {/* Product */}
      {isEdit ? (
        <p className="text-body-sm text-muted">
          Product is fixed for an existing deal. SKU {picked?.sku || "—"} · MRP {money(mrp)}
        </p>
      ) : (
        <div className="flex flex-col gap-xs">
          <button
            type="button"
            onClick={() => setPickerOpen(true)}
            className="inline-flex h-10 items-center justify-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            {picked ? "Change product" : "Pick a product"}
          </button>
          {picked ? (
            <p className="text-body-sm text-muted">
              {picked.name} · SKU {picked.sku} · MRP {money(picked.mrp)}
            </p>
          ) : null}
        </div>
      )}

      <div className="grid grid-cols-2 gap-md">
        <TextField
          label="Flash price (₹)"
          value={flashPrice}
          onChange={setFlashPrice}
          inputMode="decimal"
          helper={!priceError && off > 0 ? `${off}% off MRP` : undefined}
          error={priceError}
        />
        <TextField
          label="Stock cap"
          value={stockLimit}
          onChange={setStockLimit}
          inputMode="numeric"
          helper="Hard limit — sells out and stops here"
        />
      </div>

      <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
        <DateTimeField label="Starts" value={startAt} onChange={setStartAt} />
        <DateTimeField label="Ends" value={endAt} onChange={setEndAt} />
      </div>

      {error ? <p className="text-body-sm text-error">{error}</p> : null}

      <ModalActions
        busy={busy}
        confirmLabel={isEdit ? "Save changes" : "Create flash deal"}
        onCancel={onClose}
        onConfirm={save}
      />

      {pickerOpen ? (
        <ProductPicker onPick={onPickProduct} onClose={() => setPickerOpen(false)} />
      ) : null}
    </Modal>
  );
}

// ── Analytics ─────────────────────────────────────────────────────────

function FlashAnalyticsModal({ deal, onClose }: { deal: FlashSale; onClose: () => void }) {
  const [data, setData] = useState<FlashAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const a = await getFlashDealAnalytics(deal.id);
        if (active) setData(a);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load analytics.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [deal.id]);

  const totals = data
    ? data.series.reduce(
        (acc, r) => ({ sold: acc.sold + r.sold, taps: acc.taps + r.taps, views: acc.views + r.views }),
        { sold: 0, taps: 0, views: 0 },
      )
    : { sold: 0, taps: 0, views: 0 };
  const conversion = totals.taps > 0 ? Math.round((totals.sold / totals.taps) * 100) : 0;
  const maxTaps = data ? Math.max(1, ...data.series.map((r) => r.taps)) : 1;

  return (
    <Modal title="Flash deal analytics" onClose={onClose} wide>
      {loading ? (
        <p className="py-xl text-center text-body-sm text-subtle">Loading…</p>
      ) : error || !data ? (
        <p className="py-xl text-center text-body-sm text-error">{error ?? "No analytics."}</p>
      ) : (
        <>
          <div>
            <p className="text-title-sm text-ink">{data.productName}</p>
            <p className="mt-xs text-body-sm text-muted">
              {formatDateTime(data.startAt)} → {formatDateTime(data.endAt)}
            </p>
          </div>

          <div className="grid grid-cols-2 gap-md sm:grid-cols-4">
            <Stat label="Claimed" value={`${data.soldCount}/${data.stockLimit}`} />
            <Stat label="Views" value={totals.views.toLocaleString("en-IN")} />
            <Stat label="Taps" value={totals.taps.toLocaleString("en-IN")} />
            <Stat label="Tap → buy" value={`${conversion}%`} />
          </div>

          <div>
            <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">By hour</p>
            {data.series.length === 0 ? (
              <p className="rounded-md bg-surface-tint px-md py-md text-center text-body-sm text-muted">
                No activity recorded yet.
              </p>
            ) : (
              <div className="max-h-[40dvh] overflow-y-auto">
                {data.series.map((r) => (
                  <div key={r.hour} className="border-b border-hairline py-sm">
                    <div className="flex items-center justify-between gap-md text-body-sm">
                      <span className="text-muted">{formatDateTime(r.hour)}</span>
                      <span className="text-ink">
                        {r.sold} sold · {r.taps} taps · {r.views} views
                      </span>
                    </div>
                    <div className="mt-xs h-1.5 w-full overflow-hidden rounded-full bg-surface-tint">
                      <div
                        className="h-full rounded-full bg-flash-deal"
                        style={{ width: `${(r.taps / maxTaps) * 100}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </Modal>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md bg-surface-tint px-md py-sm">
      <p className="text-label-md text-subtle">{label}</p>
      <p className="mt-px text-title-sm text-ink">{value}</p>
    </div>
  );
}
