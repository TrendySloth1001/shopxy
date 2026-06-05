"use client";

import { useCallback, useEffect, useState } from "react";
import { Eye, Megaphone, Pause, Pencil, Play, Plus, RefreshCw, StopCircle } from "lucide-react";
import {
  ProductPicker,
  type PickedProduct,
} from "@/features/products/components/product-picker";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { DateTimeField, TextField } from "@/shared/ui/form";
import { formatDateRange, isoFromNow, nowIso } from "@/shared/datetime";
import {
  cancelPromotion,
  createPromotion,
  listPromotions,
  updatePromotion,
} from "@/features/promotions/api";
import {
  rupees,
  spendPctOfBudget,
  spendPctOfDailyCap,
  statusLabel,
} from "@/features/promotions/format";
import type { Promotion } from "@/features/promotions/schema";

export default function PromotionsPage() {
  const [promos, setPromos] = useState<Promotion[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [editing, setEditing] = useState<Promotion | "new" | null>(null);
  const [cancelTarget, setCancelTarget] = useState<Promotion | null>(null);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [busyId, setBusyId] = useState<number | null>(null);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const rows = await listPromotions();
        if (!active) return;
        setPromos(rows);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load promotions.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  async function confirmCancel() {
    if (!cancelTarget) return;
    setCancelBusy(true);
    try {
      await cancelPromotion(cancelTarget.id);
      setCancelTarget(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not cancel the promotion.");
    } finally {
      setCancelBusy(false);
    }
  }

  async function setActive(promo: Promotion, isActive: boolean) {
    setBusyId(promo.id);
    setError(null);
    try {
      await updatePromotion(promo.id, { isActive });
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not update the promotion.");
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex flex-wrap items-start justify-between gap-md">
        <div>
          <div className="flex items-center gap-sm">
            <Megaphone size={22} className="text-accent-indigo" />
            <h1 className="text-headline-md text-ink">Promotions</h1>
          </div>
          <p className="mt-xs text-body-md text-muted">
            Pay-per-impression sponsored placements. You set a budget, a daily cap and a CPM — we
            auto-pause when either limit is hit.
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
            <Plus size={16} /> New promo
          </button>
        </div>
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {loading ? (
          <p className="py-xxl text-center text-body-sm text-subtle">Loading…</p>
        ) : promos.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-accent-indigo-soft text-accent-indigo">
              <Megaphone size={22} />
            </span>
            <p className="text-body-md text-muted">No promotions yet — create one to boost a product.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-lg lg:grid-cols-2">
            {promos.map((p) => (
              <PromoCard
                key={p.id}
                promo={p}
                busy={busyId === p.id}
                onEdit={() => setEditing(p)}
                onToggleActive={(next) => setActive(p, next)}
                onCancel={() => setCancelTarget(p)}
              />
            ))}
          </div>
        )}
      </div>

      {editing ? (
        <PromotionEditor
          existing={editing === "new" ? null : editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            reload();
          }}
        />
      ) : null}

      {cancelTarget ? (
        <Modal title="Cancel promotion?" onClose={() => setCancelTarget(null)}>
          <p className="text-body-md text-muted">
            Stops spend on{" "}
            <span className="text-ink">{cancelTarget.product?.name ?? `#${cancelTarget.productId}`}</span>. This
            can&rsquo;t be resumed.
          </p>
          <ModalActions
            busy={cancelBusy}
            danger
            confirmLabel="Cancel promo"
            onCancel={() => setCancelTarget(null)}
            onConfirm={confirmCancel}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function PromoCard({
  promo,
  busy,
  onEdit,
  onToggleActive,
  onCancel,
}: {
  promo: Promotion;
  busy: boolean;
  onEdit: () => void;
  onToggleActive: (next: boolean) => void;
  onCancel: () => void;
}) {
  const status = statusLabel(promo);
  const cancelled = promo.pausedReason === "cancelled_by_merchant";
  // Paused (not cancelled) campaigns can be resumed; the backend clears the
  // auto-pause reason on re-activate. Cancelled ones are terminal.
  const canResume = !promo.isActive && !cancelled;
  return (
    <div className="rounded-lg border border-hairline p-lg">
      <div className="flex items-start gap-md">
        <p className="min-w-0 flex-1 truncate text-title-sm text-ink">
          {promo.product?.name ?? `Product #${promo.productId}`}
        </p>
        <span
          className={`inline-flex shrink-0 items-center rounded-full px-sm py-px text-body-sm font-semibold ${
            promo.isActive ? "bg-success-soft text-success" : "bg-surface-tint text-muted"
          }`}
        >
          {status}
        </span>
        <div className="flex shrink-0 items-center">
          {!cancelled ? (
            <button
              type="button"
              onClick={onEdit}
              aria-label="Edit"
              className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
            >
              <Pencil size={16} />
            </button>
          ) : null}
          {promo.isActive ? (
            <button
              type="button"
              onClick={() => onToggleActive(false)}
              disabled={busy}
              aria-label="Pause"
              className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink disabled:text-disabled"
            >
              <Pause size={16} />
            </button>
          ) : canResume ? (
            <button
              type="button"
              onClick={() => onToggleActive(true)}
              disabled={busy}
              aria-label="Resume"
              className="inline-flex size-8 items-center justify-center rounded-button text-success transition-colors hover:bg-success-soft disabled:text-disabled"
            >
              <Play size={16} />
            </button>
          ) : null}
          {promo.isActive ? (
            <button
              type="button"
              onClick={onCancel}
              aria-label="Cancel"
              className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error"
            >
              <StopCircle size={18} />
            </button>
          ) : null}
        </div>
      </div>

      <p className="mt-xs text-body-sm text-muted">{formatDateRange(promo.startAt, promo.endAt)}</p>

      <div className="mt-md flex flex-col gap-md">
        <SpendBar
          label="Spend"
          value={rupees(promo.spendPaise)}
          cap={rupees(promo.budgetPaise)}
          pct={spendPctOfBudget(promo)}
          tone="brand"
        />
        <SpendBar
          label="Today's spend"
          value={rupees(promo.spendTodayPaise)}
          cap={rupees(promo.dailyCapPaise)}
          pct={spendPctOfDailyCap(promo)}
          tone="indigo"
        />
      </div>

      <p className="mt-md flex items-center gap-xs text-body-sm text-muted">
        <Eye size={14} />
        {promo.deliveredImpressions.toLocaleString("en-IN")} impressions @ {rupees(promo.cpmPaise)}/1k
      </p>
    </div>
  );
}

function SpendBar({
  label,
  value,
  cap,
  pct,
  tone,
}: {
  label: string;
  value: string;
  cap: string;
  pct: number;
  tone: "brand" | "indigo";
}) {
  return (
    <div>
      <div className="flex items-baseline justify-between gap-md">
        <span className="text-body-sm text-muted">{label}</span>
        <span className="text-body-sm text-ink">
          {value} / {cap}
        </span>
      </div>
      <div className="mt-xs h-2 w-full overflow-hidden rounded-full bg-surface-tint">
        <div
          className={`h-full rounded-full ${tone === "brand" ? "bg-brand" : "bg-accent-indigo"}`}
          style={{ width: `${pct * 100}%` }}
        />
      </div>
    </div>
  );
}

// ── Editor ────────────────────────────────────────────────────────────

function PromotionEditor({
  existing,
  onClose,
  onSaved,
}: {
  existing: Promotion | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const isEdit = existing != null;
  const [picked, setPicked] = useState<PickedProduct | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [budget, setBudget] = useState(existing ? String(existing.budgetPaise / 100) : "1000");
  const [dailyCap, setDailyCap] = useState(existing ? String(existing.dailyCapPaise / 100) : "200");
  const [cpm, setCpm] = useState(existing ? String(existing.cpmPaise / 100) : "10");
  const [startAt, setStartAt] = useState<string | null>(existing?.startAt ?? nowIso());
  const [endAt, setEndAt] = useState<string | null>(
    existing?.endAt ?? isoFromNow(7 * 24 * 60 * 60 * 1000),
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const budgetPaise = toPaise(budget);
  const dailyPaise = toPaise(dailyCap);
  const dailyError =
    budgetPaise != null && dailyPaise != null && dailyPaise > budgetPaise
      ? "Cannot exceed the total budget."
      : null;

  async function save() {
    setError(null);
    if (!isEdit && !picked) return setError("Pick a product first.");
    const cpmPaise = toPaise(cpm);
    if (budgetPaise == null || dailyPaise == null || cpmPaise == null) {
      return setError("Enter numeric budget, daily cap and CPM.");
    }
    if (dailyPaise > budgetPaise) return setError("Daily cap cannot exceed the total budget.");
    if (!startAt || !endAt || new Date(endAt) <= new Date(startAt)) {
      return setError("End time must be after the start time.");
    }
    setBusy(true);
    try {
      if (isEdit) {
        await updatePromotion(existing.id, {
          budgetPaise,
          dailyCapPaise: dailyPaise,
          cpmPaise,
          startAt,
          endAt,
        });
      } else {
        await createPromotion({
          productId: picked!.id,
          budgetPaise,
          dailyCapPaise: dailyPaise,
          cpmPaise,
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
    <Modal title={isEdit ? "Edit promotion" : "New promotion"} onClose={onClose} wide>
      {isEdit ? (
        <div className="rounded-md bg-hero-panel px-md py-sm">
          <span className="text-body-md text-ink">
            {existing.product?.name ?? `Product #${existing.productId}`}
          </span>
          <span className="ml-sm text-body-sm text-muted">Product is fixed for an existing promo.</span>
        </div>
      ) : picked ? (
        <div className="flex items-center gap-md rounded-md bg-hero-panel px-md py-sm">
          <span className="min-w-0 flex-1 truncate text-body-md text-ink">{picked.name}</span>
          <button
            type="button"
            onClick={() => setPicked(null)}
            className="text-label-md text-brand-strong transition-colors hover:text-brand"
          >
            Change
          </button>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="inline-flex h-10 items-center justify-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
        >
          Pick a product
        </button>
      )}

      <div className="grid grid-cols-1 gap-md sm:grid-cols-3">
        <TextField
          label="Total budget (₹)"
          value={budget}
          onChange={setBudget}
          inputMode="numeric"
          helper="Lifetime cap"
        />
        <TextField
          label="Daily cap (₹)"
          value={dailyCap}
          onChange={setDailyCap}
          inputMode="numeric"
          helper={dailyError ? undefined : "Auto-pause when reached"}
          error={dailyError}
        />
        <TextField
          label="CPM (₹ / 1k)"
          value={cpm}
          onChange={setCpm}
          inputMode="numeric"
          helper="Per 1000 impressions"
        />
      </div>

      <div className="grid grid-cols-1 gap-md sm:grid-cols-2">
        <DateTimeField label="Starts" value={startAt} onChange={setStartAt} />
        <DateTimeField label="Ends" value={endAt} onChange={setEndAt} />
      </div>

      {error ? <p className="text-body-sm text-error">{error}</p> : null}

      <ModalActions
        busy={busy}
        confirmLabel={isEdit ? "Save changes" : "Create promotion"}
        onCancel={onClose}
        onConfirm={save}
      />

      {pickerOpen ? (
        <ProductPicker
          onPick={(p) => {
            setPicked(p);
            setPickerOpen(false);
          }}
          onClose={() => setPickerOpen(false)}
        />
      ) : null}
    </Modal>
  );
}

/** Rupee string → integer paise, or null when not a positive number. */
function toPaise(rupeeValue: string): number | null {
  const n = Number(rupeeValue);
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.round(n * 100);
}
