"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { Eye, Megaphone, Pause, Pencil, Play, Plus, RefreshCw, StopCircle } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { formatDateRange } from "@/shared/datetime";
import { cancelPromotion, listPromotions, updatePromotion } from "@/features/promotions/api";
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
      <PageHeader
        icon={Megaphone}
        tone="indigo"
        title="Promotions"
        subtitle="Pay-per-impression sponsored placements. You set a budget, a daily cap and a CPM — we auto-pause when either limit is hit."
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
        <Link
          href="/dashboard/promotions/new"
          className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Plus size={16} /> New promo
        </Link>
      </PageHeader>

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
            <Link
              href="/dashboard/promotions/new"
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <Plus size={16} /> New promo
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-lg lg:grid-cols-2">
            {promos.map((p) => (
              <PromoCard
                key={p.id}
                promo={p}
                busy={busyId === p.id}
                onToggleActive={(next) => setActive(p, next)}
                onCancel={() => setCancelTarget(p)}
              />
            ))}
          </div>
        )}
      </div>

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
  onToggleActive,
  onCancel,
}: {
  promo: Promotion;
  busy: boolean;
  onToggleActive: (next: boolean) => void;
  onCancel: () => void;
}) {
  const status = statusLabel(promo);
  const cancelled = promo.pausedReason === "cancelled_by_merchant";
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
            <Link
              href={`/dashboard/promotions/${promo.id}/edit`}
              aria-label="Edit"
              className="inline-flex size-8 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
            >
              <Pencil size={16} />
            </Link>
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
