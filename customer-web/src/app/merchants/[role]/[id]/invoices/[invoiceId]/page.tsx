"use client";

import { useEffect, useState, useCallback, startTransition } from "react";
import { useParams } from "next/navigation";
import { AlertCircle, CalendarDays, StickyNote, Store, User } from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { fetchInvoiceDetail } from "@/features/merchant-ledger/api";
import {
  InvoiceStatusBadge,
  SkeletonLine,
  SkeletonBlock,
} from "@/features/merchant-ledger/components/shared";
import type { InvoiceDetail, MerchantRole } from "@/features/merchant-ledger/types";
import { formatINR } from "@/shared/format";
import { formatDate } from "@/shared/datetime";

function fmtQty(qty: number, unit: string) {
  const q = Number.isInteger(qty) ? qty.toString() : qty.toFixed(2);
  return `${q} ${unit}`;
}

function fmtTax(pct: number) {
  if (pct <= 0) return null;
  return Number.isInteger(pct) ? `${pct}% tax` : `${pct.toFixed(2)}% tax`;
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

function InvoiceDetailSkeleton() {
  return (
    <div className="space-y-xl">
      {/* Header */}
      <div className="flex justify-between items-start">
        <div className="space-y-sm flex-1">
          <SkeletonLine className="h-3 w-28" />
          <SkeletonLine className="h-6 w-48" />
          <SkeletonLine className="h-3 w-32" />
        </div>
        <SkeletonBlock className="h-6 w-16 rounded-full" />
      </div>
      <div className="h-px bg-hairline" />
      {/* Counterparty */}
      <div className="flex gap-md">
        <SkeletonBlock className="h-10 w-10 shrink-0 rounded-md" />
        <div className="space-y-xs flex-1">
          <SkeletonLine className="h-3 w-20" />
          <SkeletonLine className="h-4 w-40" />
          <SkeletonLine className="h-3 w-28" />
        </div>
      </div>
      <div className="h-px bg-hairline" />
      {/* Items */}
      <div className="space-y-md">
        <SkeletonLine className="h-3 w-16" />
        {[1, 2, 3].map((i) => (
          <div key={i} className="flex justify-between items-start py-md border-t border-hairline">
            <div className="flex-1 space-y-xs">
              <SkeletonLine className="h-4 w-48" />
              <SkeletonLine className="h-3 w-64" />
            </div>
            <SkeletonLine className="h-4 w-16" />
          </div>
        ))}
      </div>
      <div className="h-px bg-hairline" />
      {/* Totals */}
      <div className="space-y-xs">
        {[1, 2, 3].map((i) => (
          <div key={i} className="flex justify-between py-xs">
            <SkeletonLine className="h-3 w-20" />
            <SkeletonLine className="h-3 w-20" />
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Detail view ─────────────────────────────────────────────────────────────

function TotalsRow({
  label,
  value,
  strong,
  valueClass,
}: {
  label: string;
  value: string;
  strong?: boolean;
  valueClass?: string;
}) {
  const labelCls = strong
    ? "text-body-md font-extrabold text-ink"
    : "text-body-sm text-muted";
  const valCls = strong
    ? `text-title-sm font-extrabold text-ink tabular-nums ${valueClass ?? ""}`
    : `text-body-sm font-bold text-ink tabular-nums ${valueClass ?? ""}`;
  return (
    <div className="flex items-baseline justify-between py-xs">
      <span className={labelCls}>{label}</span>
      <span className={valCls}>{value}</span>
    </div>
  );
}

function InvoiceDetailContent({
  invoice,
  role,
}: {
  invoice: InvoiceDetail;
  role: MerchantRole;
}) {
  const isSale = invoice.type === "SALE" || invoice.type === "SALES";
  const eyebrow = isSale ? "SALES INVOICE" : "PURCHASE BILL";
  const counterpartyEyebrow = isSale ? "ISSUED TO" : "ISSUED BY";
  const cpName = isSale
    ? invoice.customerName ?? "Customer"
    : invoice.vendorName ?? "Vendor";
  const cpPhone = isSale ? invoice.customerPhone : invoice.vendorPhone;
  const cpGstin = isSale ? invoice.customerGstin : invoice.vendorGstin;
  const Icon = role === "party" ? User : Store;

  return (
    <div className="space-y-xl">
      {/* Header */}
      <div className="flex justify-between items-start gap-md">
        <div className="space-y-xs flex-1 min-w-0">
          <p className="text-[10px] font-extrabold tracking-[1.2px] text-brand uppercase">
            {eyebrow}
          </p>
          <h1 className="text-headline-sm font-extrabold text-ink truncate">
            {invoice.invoiceNo}
          </h1>
          <div className="flex items-center gap-xs text-body-sm text-muted">
            <CalendarDays size={14} />
            <span>{formatDate(invoice.invoiceDate)}</span>
          </div>
        </div>
        <InvoiceStatusBadge status={invoice.status} />
      </div>

      <div className="h-px bg-hairline my-lg" />

      {/* Counterparty */}
      <div className="flex gap-md">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-brand-soft">
          <Icon size={18} className="text-brand" />
        </span>
        <div className="min-w-0">
          <p className="text-[10px] font-extrabold tracking-[0.9px] text-muted uppercase mb-xs">
            {counterpartyEyebrow}
          </p>
          <p className="text-title-sm font-extrabold text-ink leading-tight">{cpName}</p>
          {cpPhone && <p className="text-body-sm text-muted mt-xs">{cpPhone}</p>}
          {cpGstin && <p className="text-body-sm text-muted">GSTIN {cpGstin}</p>}
        </div>
      </div>

      <div className="h-px bg-hairline my-lg" />

      {/* Items section */}
      <div>
        <div className="flex justify-between items-center mb-sm">
          <p className="text-[10px] font-extrabold tracking-[1.4px] text-muted uppercase">
            ITEMS
          </p>
          <p className="text-[10px] font-bold text-muted">
            {invoice.items.length} item{invoice.items.length !== 1 ? "s" : ""}
          </p>
        </div>
        <div className="border-t border-hairline">
          {invoice.items.map((item, i) => {
            const tax = fmtTax(item.taxPercent);
            const meta = [
              fmtQty(item.quantity, item.unit),
              `@ ${formatINR(item.unitPrice, { decimals: 2 })}`,
              tax,
            ]
              .filter(Boolean)
              .join("  ·  ");
            return (
              <div
                key={item.id}
                className={`flex items-start justify-between gap-md py-md ${i > 0 ? "border-t border-hairline" : ""}`}
              >
                <div className="flex-1 min-w-0">
                  <p className="text-body-md font-bold text-ink leading-snug">{item.productName}</p>
                  <p className="text-body-sm text-muted mt-[2px]">{meta}</p>
                </div>
                <p className="text-body-md font-extrabold text-ink tabular-nums shrink-0">
                  {formatINR(item.total, { decimals: 2 })}
                </p>
              </div>
            );
          })}
        </div>
      </div>

      <div className="h-px bg-hairline my-lg" />

      {/* Totals */}
      <div>
        <TotalsRow label="Subtotal" value={formatINR(invoice.subtotal, { decimals: 2 })} />
        <TotalsRow label="Tax" value={formatINR(invoice.taxAmount, { decimals: 2 })} />
        {invoice.discount > 0 && (
          <TotalsRow
            label="Discount"
            value={`− ${formatINR(invoice.discount, { decimals: 2 })}`}
            valueClass="text-success"
          />
        )}
        <div className="h-px bg-hairline my-sm" />
        <TotalsRow label="Total" value={formatINR(invoice.total, { decimals: 2 })} strong />
      </div>

      {/* Note */}
      {invoice.note && (
        <>
          <div className="h-px bg-hairline my-lg" />
          <div>
            <p className="text-[10px] font-extrabold tracking-[1.4px] text-muted uppercase mb-sm">
              NOTE
            </p>
            <div className="border-t border-hairline pt-md flex gap-sm">
              <StickyNote size={14} className="text-muted mt-[2px] shrink-0" />
              <p className="text-body-sm text-ink leading-relaxed">{invoice.note}</p>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

function InvoiceDetailPageContent() {
  const params = useParams<{ role: string; id: string; invoiceId: string }>();
  const role = params.role as MerchantRole;
  const id = params.id;
  const invoiceId = params.invoiceId;

  const [invoice, setInvoice] = useState<InvoiceDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchInvoiceDetail(role, id, invoiceId);
      setInvoice(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load invoice.");
    } finally {
      setLoading(false);
    }
  }, [role, id, invoiceId]);

  useEffect(() => {
    startTransition(() => { void load(); });
  }, [load]);

  return (
    <div className="mx-auto max-w-shell px-0 sm:px-lg py-xxxl">
      <div className="mx-auto max-w-content px-lg sm:px-0">
        {loading && !invoice && <InvoiceDetailSkeleton />}

        {!loading && error && (
          <div className="flex flex-col items-center gap-md py-huge text-center">
            <AlertCircle size={40} className="text-error" />
            <p className="text-body-md text-muted">{error}</p>
            <button
              onClick={load}
              className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong"
            >
              Retry
            </button>
          </div>
        )}

        {!loading && !error && invoice && (
          <InvoiceDetailContent invoice={invoice} role={role} />
        )}
      </div>
    </div>
  );
}

export default function InvoiceDetailPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <InvoiceDetailPageContent />
    </RequireAuth>
  );
}
