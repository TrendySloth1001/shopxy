"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ArrowDown, ArrowUp, ArrowRight } from "lucide-react";
import { Modal } from "@/shared/ui/modal";
import { qty as fmtQty } from "@/features/products/format";
import { unitLabel } from "@/features/products/units";
import { listStockTransactions } from "./api";
import {
  hasSourceDocument,
  isReversal,
  isStockIn,
  reasonCodeLabel,
  sourceTypeLabel,
  type StockTxn,
} from "./schema";

/**
 * Full chronological stock ledger for one product — the web mirror of the
 * Flutter `StockLedgerPage`, shown as a bottom-sheet/dialog. Each row shows when
 * the movement happened, its reason, the signed quantity, the running balance,
 * the source document, supplier and operator. Rows backed by an invoice/challan
 * link straight to that document.
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
          setError(e instanceof Error ? e.message : "Could not load the ledger.");
          setEntries([]);
        }
      }
    })();
    return () => {
      active = false;
    };
  }, [productId]);

  return (
    <Modal title="Stock ledger" onClose={onClose} wide>
      <p className="-mt-sm text-body-md text-muted">{productName}</p>

      {error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : entries === null ? (
        <p className="py-lg text-center text-body-sm text-muted">Loading ledger…</p>
      ) : entries.length === 0 ? (
        <p className="py-lg text-center text-body-md text-muted">
          No movements recorded for this product yet.
        </p>
      ) : (
        <ul className="flex flex-col gap-sm">
          {entries.map((e) => (
            <LedgerEntry key={e.id} entry={e} unit={productUnit} onNavigate={onClose} />
          ))}
        </ul>
      )}
    </Modal>
  );
}

function LedgerEntry({
  entry,
  unit,
  onNavigate,
}: {
  entry: StockTxn;
  unit?: string | null;
  onNavigate: () => void;
}) {
  const stockIn = isStockIn(entry);
  const reversal = isReversal(entry);
  const accent = stockIn ? "text-brand-strong" : "text-error";
  const sign = stockIn ? "+" : "−";
  const unitStr = unit ?? entry.productUnit ?? "";
  const unitText = unitStr ? ` ${unitLabel(unitStr)}` : "";
  const sourceHref = sourceLink(entry);

  const hasMeta =
    hasSourceDocument(entry) ||
    entry.vendor?.name ||
    entry.supplierName ||
    entry.note ||
    entry.stockAfter != null;

  return (
    <li className="rounded-lg border border-hairline p-md">
      <div className="flex items-start gap-md">
        <span
          className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-md border ${
            stockIn ? "border-brand-strong/40" : "border-error/40"
          } ${accent}`}
        >
          {stockIn ? <ArrowDown size={16} /> : <ArrowUp size={16} />}
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-sm">
            <span className="truncate text-body-md font-semibold text-ink">
              {reasonCodeLabel(entry.reasonCode)}
            </span>
            {reversal ? (
              <span className="rounded-full bg-surface-tint px-sm py-px text-label-md text-muted">
                Reversal
              </span>
            ) : null}
          </div>
          <p className="mt-px text-body-sm text-muted">{formatDateTime(entry.createdAt)}</p>
        </div>
        <span className={`shrink-0 text-body-lg font-bold tabular-nums ${accent}`}>
          {sign}
          {fmtQty(entry.quantity)}
          {unitText}
        </span>
      </div>

      {hasMeta ? (
        <div className="mt-md border-t border-hairline pt-md">
          <div className="flex flex-wrap items-center justify-between gap-x-md gap-y-xs">
            <div className="flex flex-wrap items-center gap-x-sm gap-y-xs">
              <span className={`rounded-full px-sm py-px text-label-md ${sourceToneClass(entry)}`}>
                {sourceTypeLabel(entry.sourceType)}
              </span>
              {entry.vendor?.name || entry.supplierName ? (
                <span className="text-body-sm text-muted">
                  {entry.vendor?.name ?? entry.supplierName}
                </span>
              ) : null}
              {entry.createdBy?.name ? (
                <span className="text-body-sm text-subtle">by {entry.createdBy.name}</span>
              ) : null}
            </div>
            {entry.stockAfter != null ? (
              <span className="text-body-sm font-medium tabular-nums text-muted">
                Bal: {fmtQty(entry.stockAfter)}
              </span>
            ) : null}
          </div>
          {entry.note ? <p className="mt-xs text-body-sm text-muted">{entry.note}</p> : null}
          {sourceHref ? (
            <div className="mt-sm flex justify-end">
              <Link
                href={sourceHref}
                onClick={onNavigate}
                className="inline-flex items-center gap-xs text-label-md font-semibold text-ink transition-colors hover:text-brand-strong"
              >
                View source <ArrowRight size={14} />
              </Link>
            </div>
          ) : null}
        </div>
      ) : null}
    </li>
  );
}

/** Route to the source document, or null when there's nothing to open. */
function sourceLink(entry: StockTxn): string | null {
  if (!hasSourceDocument(entry) || entry.sourceId == null) return null;
  if (entry.sourceType === "INVOICE") return `/dashboard/invoices/${entry.sourceId}`;
  if (entry.sourceType === "CHALLAN") return `/dashboard/challans/${entry.sourceId}`;
  return null;
}

/** Soft badge colour for the source-type chip, keyed off the reason. */
function sourceToneClass(entry: StockTxn): string {
  if (isReversal(entry)) return "bg-surface-tint text-muted";
  switch (entry.reasonCode) {
    case "SALE":
    case "PURCHASE":
    case "OPENING":
    case "RETURN_IN":
      return isStockIn(entry) ? "bg-success-soft text-success" : "bg-surface-tint text-muted";
    case "DAMAGE":
    case "EXPIRED":
    case "SHRINKAGE":
      return "bg-error-soft text-error";
    case "RECOUNT":
    case "RETURN_OUT":
      return "bg-accent-amber-soft text-accent-amber";
    default:
      return "bg-surface-tint text-muted";
  }
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
