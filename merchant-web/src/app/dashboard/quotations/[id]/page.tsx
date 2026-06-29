"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { Calculator, Download, ReceiptText, XCircle } from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { TextAreaField } from "@/shared/ui/form";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import {
  cancelQuotation,
  declineQuotationRequest,
  getQuotation,
  quotationPdfUrl,
} from "@/features/quotations/api";
import {
  QUOTATION_STATUS_CLASSES,
  QUOTATION_STATUS_LABELS,
  quotationPartyName,
  type Quotation,
  type QuotationLine,
} from "@/features/quotations/schema";
import { DetailSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/quotations";

export default function QuotationDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [quote, setQuote] = useState<Quotation | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [confirmCancel, setConfirmCancel] = useState(false);
  const [declineOpen, setDeclineOpen] = useState(false);
  const [declineNote, setDeclineNote] = useState("");

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const q = await getQuotation(id);
        if (!active) return;
        setQuote(q);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the quotation.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce]);

  async function onCancel() {
    setBusy(true);
    setActionError(null);
    try {
      await cancelQuotation(id);
      setConfirmCancel(false);
      setNonce((n) => n + 1);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not cancel the quotation.");
    } finally {
      setBusy(false);
    }
  }

  async function onDecline() {
    setBusy(true);
    setActionError(null);
    try {
      await declineQuotationRequest(id, declineNote.trim() || undefined);
      setDeclineOpen(false);
      setNonce((n) => n + 1);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not decline the request.");
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return <DetailSkeleton />;
  }
  if (error || !quote) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label="Quotations" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? "Quotation not found."}
        </p>
      </div>
    );
  }

  const isRequested = quote.status === "REQUESTED";
  const isPending = quote.status === "PENDING";
  const meta = isRequested
    ? `From ${quotationPartyName(quote)} · requested ${formatDateTime(quote.createdAt)}`
    : `To ${quotationPartyName(quote)} · ${formatDateTime(quote.createdAt)}`;

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Quotations" />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-sm">
            <h1 className="text-headline-md text-ink">{quote.quotationNo}</h1>
            <span
              className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
                QUOTATION_STATUS_CLASSES[quote.status] ?? "bg-surface-tint text-muted"
              }`}
            >
              {QUOTATION_STATUS_LABELS[quote.status] ?? quote.status}
            </span>
          </div>
          <p className="mt-xs text-body-sm text-muted">{meta}</p>
          {quote.invoice ? (
            <Link
              href={`/dashboard/invoices/${quote.invoice.id}`}
              className="mt-sm inline-flex items-center gap-xs rounded-full bg-success-soft px-md py-xs text-body-sm font-semibold text-success transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-success-soft"
            >
              <ReceiptText size={14} /> Invoice {quote.invoice.invoiceNo}
            </Link>
          ) : null}
          {quote.status === "DECLINED" && quote.declineNote ? (
            <p className="mt-xs text-body-sm text-error">Reason: {quote.declineNote}</p>
          ) : null}
        </div>
        <div className="flex shrink-0 flex-wrap items-center gap-sm">
          <Link
            href={`/dashboard/reports?tab=calculator&quotation=${id}`}
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Calculator size={16} /> Open in calculator
          </Link>
          <a
            href={quotationPdfUrl(id)}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Download size={16} /> PDF
          </a>
        </div>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{actionError}</p>
      ) : null}

      {/* Items */}
      <Divider className="my-xl" />
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Items ({quote.items.length})</h2>
      {quote.items.map((it, i) => (
        <LineRow key={i} line={it} />
      ))}

      {/* Totals */}
      <div className="mt-xl ml-auto w-full max-w-form border-t border-hairline pt-md">
        <Row label="Subtotal" value={quote.subtotal} />
        <Row label="GST" value={quote.taxAmount} />
        <div className="mt-sm flex items-center justify-between border-t border-hairline pt-sm">
          <span className="text-title-md text-ink">Total</span>
          <span className="text-title-lg font-bold text-ink">{formatINR2(quote.total)}</span>
        </div>
      </div>

      {/* Note */}
      {quote.note ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">
            {isRequested ? "Customer's note" : "Note"}
          </h2>
          <p className="text-body-md text-muted">{quote.note}</p>
        </>
      ) : null}

      {/* Actions */}
      {isRequested ? (
        <div className="mt-xxl flex flex-wrap items-center gap-sm">
          <button
            type="button"
            onClick={() => setDeclineOpen(true)}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-error transition-colors hover:bg-error-soft disabled:text-disabled"
          >
            Decline
          </button>
          <Link
            href={`/dashboard/quotations/${id}/respond`}
            className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong"
          >
            Price &amp; send
          </Link>
        </div>
      ) : isPending ? (
        <div className="mt-xxl flex flex-wrap items-center gap-sm">
          <button
            type="button"
            onClick={() => setConfirmCancel(true)}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-error transition-colors hover:bg-error-soft disabled:text-disabled"
          >
            <XCircle size={16} /> Cancel quotation
          </button>
        </div>
      ) : null}

      {confirmCancel ? (
        <Modal title="Cancel this quotation?" onClose={() => setConfirmCancel(false)}>
          <p className="text-body-md text-muted">The customer will no longer be able to accept it.</p>
          <ModalActions
            busy={busy}
            danger
            confirmLabel="Cancel quotation"
            onCancel={() => setConfirmCancel(false)}
            onConfirm={onCancel}
          />
        </Modal>
      ) : null}
      {declineOpen ? (
        <Modal title="Decline this request?" onClose={() => setDeclineOpen(false)}>
          <p className="text-body-md text-muted">
            Let the customer know why you can&rsquo;t quote this (optional).
          </p>
          <TextAreaField label="Reason (optional)" value={declineNote} onChange={setDeclineNote} rows={2} />
          <ModalActions
            busy={busy}
            danger
            confirmLabel="Decline"
            onCancel={() => setDeclineOpen(false)}
            onConfirm={onDecline}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function LineRow({ line }: { line: QuotationLine }) {
  const total = line.lineTotal ?? line.quantity * line.unitPrice * (1 + line.taxPercent / 100);
  return (
    <div className="flex items-start gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{line.name ?? "Product"}</p>
        <p className="text-body-sm text-muted">
          {line.quantity} × {formatINR2(line.unitPrice)}
          {line.taxPercent > 0 ? ` · ${line.taxPercent}% GST` : ""}
        </p>
      </div>
      <span className="shrink-0 text-body-md font-semibold text-ink">{formatINR2(total)}</span>
    </div>
  );
}

function Row({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center justify-between py-xs">
      <span className="text-body-md text-muted">{label}</span>
      <span className="text-body-md tabular-nums text-ink">{formatINR2(value)}</span>
    </div>
  );
}
