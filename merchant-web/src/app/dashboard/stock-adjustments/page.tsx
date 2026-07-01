"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { ArrowDownLeft, ArrowUpRight, ChevronRight, Plus, RefreshCw, SlidersHorizontal } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { formatDateTime } from "@/shared/datetime";
import { listAdjustments } from "@/features/stock-adjustments/api";
import {
  ADJUSTMENT_REASON_CLASSES,
  adjustmentItemCount,
  type Adjustment,
} from "@/features/stock-adjustments/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

export default function StockAdjustmentsPage() {
  const t = useTranslations("stockAdjustments");
  const [rows, setRows] = useState<Adjustment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listAdjustments();
        if (!active) return;
        setRows(data);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("list.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, t]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={SlidersHorizontal}
        tone="indigo"
        title={t("list.title")}
        subtitle={t("list.subtitle")}
      >
        <button
          type="button"
          onClick={() => setNonce((n) => n + 1)}
          disabled={loading}
          aria-label={t("actions.refresh")}
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="stock" label={t("actions.newAdjustment")}>
          <Link
            href="/dashboard/stock-adjustments/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> {t("actions.newAdjustment")}
          </Link>
        </MaybeLocked>
      </PageHeader>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {loading ? (
          <ListRowsSkeleton />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-accent-indigo-soft text-accent-indigo">
              <SlidersHorizontal size={22} />
            </span>
            <p className="text-body-md text-muted">{t("list.empty")}</p>
            <MaybeLocked area="stock" label={t("actions.newAdjustment")}>
              <Link
                href="/dashboard/stock-adjustments/new"
                className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
              >
                <Plus size={16} /> {t("actions.newAdjustment")}
              </Link>
            </MaybeLocked>
          </div>
        ) : (
          rows.map((a) => <AdjustmentRow key={a.id} adjustment={a} />)
        )}
      </div>
    </div>
  );
}

function AdjustmentRow({ adjustment }: { adjustment: Adjustment }) {
  const t = useTranslations("stockAdjustments");
  const items = adjustmentItemCount(adjustment);
  const isIn = adjustment.direction === "IN";
  return (
    <Link
      href={`/dashboard/stock-adjustments/${adjustment.id}`}
      className="flex items-center gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint"
    >
      <span
        className={`flex size-10 shrink-0 items-center justify-center rounded-full ${
          isIn ? "bg-success-soft text-success" : "bg-error-soft text-error"
        }`}
      >
        {isIn ? <ArrowDownLeft size={18} /> : <ArrowUpRight size={18} />}
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-sm">
          <span className="truncate text-body-md text-ink">{adjustment.adjustmentNo}</span>
          <span
            className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
              ADJUSTMENT_REASON_CLASSES[adjustment.reasonCode] ?? "bg-surface-tint text-muted"
            }`}
          >
            {t(`reason.${adjustment.reasonCode}`)}
          </span>
        </div>
        <p className="text-body-sm text-subtle">
          {formatDateTime(adjustment.createdAt)} · {items}{" "}
          {items === 1 ? t("list.itemOne") : t("list.itemOther")}
        </p>
      </div>
      <ChevronRight size={18} className="shrink-0 text-subtle" />
    </Link>
  );
}
