"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { ArrowDown, ArrowUp, ChevronRight } from "@/shared/icons";
import { Modal } from "@/shared/ui/modal";
import { qty as fmtQty } from "@/features/products/format";
import { unitLabel } from "@/features/products/units";
import { listStockTransactions } from "./api";
import {
  hasSourceDocument,
  isReversal,
  isStockIn,
  type StockTxn,
} from "./schema";

/**
 * Full chronological stock ledger for one product — the web mirror of the
 * Flutter `StockLedgerPage`, shown as a bottom-sheet/dialog. Each row shows when
 * the movement happened, its reason, the signed quantity, the running balance,
 * the source document, supplier and operator. Rows backed by an invoice/challan
 * are clickable and link straight to that document.
 */
export function StockLedgerSheet({
  productId,
  productName,
  productUnit,
  onClose,
}: {
  productId: number;
  productName: string;
  productUnit?: string | null;
  onClose: () => void;
}) {
  const t = useTranslations("stockAdjustments");
  const [entries, setEntries] = useState<StockTxn[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const rows = await listStockTransactions({ productId, limit: 200 });
        if (active) {
          setEntries(rows);
          setError(null);
        }
      } catch (e) {
        if (active) {
          setError(e instanceof Error ? e.message : t("ledger.loadError"));
          setEntries([]);
        }
      }
    })();
    return () => {
      active = false;
    };
  }, [productId, t]);

  return (
    <Modal title={t("ledger.title")} onClose={onClose} wide>
      <p className="text-body-sm text-muted">{productName}</p>

      {error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : entries === null ? (
        <LedgerSkeleton />
      ) : entries.length === 0 ? (
        <p className="py-xl text-center text-body-md text-muted">
          {t("ledger.empty")}
        </p>
      ) : (
        <ul className="-mx-sm divide-y divide-hairline">
          {entries.map((e) => (
            <LedgerEntry key={e.id} entry={e} unit={productUnit} onNavigate={onClose} />
          ))}
        </ul>
      )}
    </Modal>
  );
}

const LEDGER_REASON_KEYS = new Set([
  "SALE",
  "PURCHASE",
  "OPENING",
  "DAMAGE",
  "EXPIRED",
  "SHRINKAGE",
  "RECOUNT",
  "RETURN_IN",
  "RETURN_OUT",
  "TRANSFER_IN",
  "TRANSFER_OUT",
]);

function LedgerEntry({
  entry,
  unit,
  onNavigate,
}: {
  entry: StockTxn;
  unit?: string | null;
  onNavigate: () => void;
}) {
  const t = useTranslations("stockAdjustments");
  const stockIn = isStockIn(entry);
  const accent = stockIn ? "text-success" : "text-error";
  const iconBg = stockIn ? "bg-success-soft" : "bg-error-soft";
  const sign = stockIn ? "+" : "−";
  const unitStr = unit ?? entry.productUnit ?? "";
  const unitText = unitStr ? ` ${unitLabel(unitStr)}` : "";
  const href = sourceLink(entry);
  const reasonLabel =
    entry.reasonCode && LEDGER_REASON_KEYS.has(entry.reasonCode)
      ? t(`ledgerReason.${entry.reasonCode}`)
      : t("ledgerReason.movement");

  // "27 Jun 2026, 11:09 am · Acme traders · by Nikhil Kumawat"
  const meta = [
    formatDateTime(entry.createdAt),
    entry.vendor?.name ?? entry.supplierName ?? null,
    entry.createdBy?.name ? t("ledger.byName", { name: entry.createdBy.name }) : null,
  ]
    .filter(Boolean)
    .join(" · ");

  const inner = (
    <div className="flex items-start gap-md">
      <span
        className={`mt-px flex h-8 w-8 shrink-0 items-center justify-center rounded-full ${iconBg} ${accent}`}
      >
        {stockIn ? <ArrowDown size={15} /> : <ArrowUp size={15} />}
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline justify-between gap-md">
          <span className="flex min-w-0 items-center gap-sm">
            <span className="truncate text-body-md font-semibold text-ink">
              {reasonLabel}
            </span>
            {isReversal(entry) ? (
              <span className="shrink-0 rounded-full bg-surface-tint px-sm py-px text-label-md text-muted">
                {t("ledger.reversal")}
              </span>
            ) : null}
          </span>
          <span className={`shrink-0 text-body-md font-bold tabular-nums ${accent}`}>
            {sign}
            {fmtQty(entry.quantity)}
            {unitText}
          </span>
        </div>

        <div className="mt-xs flex items-baseline justify-between gap-md">
          <span className="truncate text-body-sm text-muted">{meta}</span>
          {entry.stockAfter != null ? (
            <span className="shrink-0 text-body-sm tabular-nums text-muted">
              {t("ledger.balance", { value: fmtQty(entry.stockAfter) })}
            </span>
          ) : null}
        </div>

        {entry.note ? (
          <div className="mt-xs flex items-center gap-xs">
            <span className="truncate text-body-sm text-subtle group-hover:text-ink">
              {entry.note}
            </span>
            {href ? (
              <ChevronRight size={14} className="shrink-0 text-subtle group-hover:text-ink" />
            ) : null}
          </div>
        ) : null}
      </div>
    </div>
  );

  if (href) {
    return (
      <li>
        <Link
          href={href}
          onClick={onNavigate}
          className="group block rounded-md px-sm py-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          {inner}
        </Link>
      </li>
    );
  }
  return <li className="px-sm py-md">{inner}</li>;
}

function LedgerSkeleton() {
  return (
    <ul className="-mx-sm divide-y divide-hairline">
      {[0, 1, 2, 3].map((i) => (
        <li key={i} className="flex items-start gap-md px-sm py-md">
          <span className="h-8 w-8 shrink-0 animate-pulse rounded-full bg-surface-tint" />
          <div className="flex-1 space-y-xs">
            <div className="h-3 w-1/3 animate-pulse rounded bg-surface-tint" />
            <div className="h-3 w-2/3 animate-pulse rounded bg-surface-tint" />
          </div>
        </li>
      ))}
    </ul>
  );
}

/** Route to the source document, or null when there's nothing to open. */
function sourceLink(entry: StockTxn): string | null {
  if (!hasSourceDocument(entry) || entry.sourceId == null) return null;
  if (entry.sourceType === "INVOICE") return `/dashboard/invoices/${entry.sourceId}`;
  if (entry.sourceType === "CHALLAN") return `/dashboard/challans/${entry.sourceId}`;
  return null;
}

const dateTimeFmt = new Intl.DateTimeFormat("en-IN", {
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});
function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "—" : dateTimeFmt.format(d);
}
