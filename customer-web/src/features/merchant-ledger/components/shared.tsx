"use client";

import {
  CheckCircle,
  Clock,
  XCircle,
  Ban,
  AlertCircle,
  ReceiptText,
  FileQuestion,
} from "@/shared/icons";

export function StatusBadge({
  label,
  color,
  bg,
}: {
  label: string;
  color: string;
  bg: string;
}) {
  return (
    <span
      className={`inline-flex items-center gap-xs rounded-full px-sm py-[3px] text-micro font-extrabold tracking-[0.4px] ${color} ${bg}`}
    >
      {label}
    </span>
  );
}

export function InvoiceStatusBadge({ status }: { status: string }) {
  const s = (status ?? "").toUpperCase();
  let label = "Unpaid";
  let color = "text-warning";
  let bg = "bg-warning-soft";
  if (s === "PAID") { label = "Paid"; color = "text-success"; bg = "bg-success-soft"; }
  else if (s === "PARTIAL" || s === "PARTIALLY_PAID") { label = "Partial"; color = "text-info"; bg = "bg-info-soft"; }
  else if (s === "CANCELLED" || s === "VOID") { label = "Cancelled"; color = "text-muted"; bg = "bg-surface-tint"; }
  return <StatusBadge label={label} color={color} bg={bg} />;
}

export function QuotationStatusBadge({ status }: { status: string }) {
  let label = status;
  let color = "text-muted";
  let bg = "bg-surface-tint";
  switch (status) {
    case "REQUESTED": label = "Requested"; color = "text-brand"; bg = "bg-brand-soft"; break;
    case "PENDING": label = "Awaiting you"; color = "text-warning"; bg = "bg-warning-soft"; break;
    case "ACCEPTED": label = "Accepted"; color = "text-success"; bg = "bg-success-soft"; break;
    case "DECLINED": label = "Declined"; color = "text-error"; bg = "bg-error-soft"; break;
    case "CANCELLED": label = "Withdrawn"; color = "text-muted"; bg = "bg-surface-tint"; break;
    case "EXPIRED": label = "Expired"; color = "text-muted"; bg = "bg-surface-tint"; break;
  }
  return <StatusBadge label={label} color={color} bg={bg} />;
}

export type SnackTone = "success" | "error" | "info";
export interface SnackMsg { message: string; tone: SnackTone }

export function Snackbar({ snack }: { snack: SnackMsg | null }) {
  if (!snack) return null;
  const bg = snack.tone === "success" ? "bg-success" : snack.tone === "error" ? "bg-error" : "bg-info";
  return (
    <div
      role="status"
      aria-live="polite"
      className={`fixed bottom-xl left-1/2 z-50 -translate-x-1/2 rounded-lg ${bg} px-lg py-sm text-label-md font-bold text-white shadow-snackbar max-w-narrow text-center pointer-events-none`}
    >
      {snack.message}
    </div>
  );
}

export function PageError({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center py-huge px-lg text-center gap-md">
      <AlertCircle size={40} className="text-error" />
      <p className="text-body-md text-muted">{message}</p>
      <button
        onClick={onRetry}
        className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        Retry
      </button>
    </div>
  );
}

export function InvoiceEmptyState() {
  return (
    <div className="flex flex-col items-center justify-center py-huge px-lg text-center gap-md">
      <ReceiptText size={48} className="text-muted" />
      <p className="text-title-sm font-extrabold text-ink">No invoices yet</p>
      <p className="text-body-md text-muted max-w-snug">
        Invoices will appear here once the shop issues one to your account.
      </p>
    </div>
  );
}

export function QuotationEmptyState({ onRequest }: { onRequest?: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center py-huge px-lg text-center gap-md">
      <FileQuestion size={48} className="text-muted" />
      <p className="text-title-sm font-extrabold text-ink">No quotations yet</p>
      <p className="text-body-md text-muted max-w-snug">
        Request a quote from the shop catalogue to get started.
      </p>
      {onRequest && (
        <button
          onClick={onRequest}
          className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md font-bold text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          Request a quote
        </button>
      )}
    </div>
  );
}

export function SkeletonLine({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded-sm bg-surface-tint ${className}`} />;
}

export function SkeletonBlock({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded-md bg-surface-tint ${className}`} />;
}

export function TxnIcon({ type }: { type: string }) {
  switch (type) {
    case "DEPOSIT":
      return (
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-success-soft">
          <CheckCircle size={18} className="text-success" />
        </span>
      );
    case "REFUND":
      return (
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-error-soft">
          <XCircle size={18} className="text-error" />
        </span>
      );
    case "FORFEIT":
      return (
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-error-soft">
          <Ban size={18} className="text-error" />
        </span>
      );
    default:
      return (
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-accent-indigo-soft">
          <Clock size={18} className="text-accent-indigo" />
        </span>
      );
  }
}
