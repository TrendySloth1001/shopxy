"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  ArchiveDown,
  ArchiveRestore,
  Calculator,
  Download,
  ReceiptText,
  XCircle,
} from "@/shared/icons";
import { BackLink } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { TextAreaField } from "@/shared/ui/form";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import {
  cancelQuotation,
  setQuotationArchived,
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
  const t = useTranslations("quotations");
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const id = params.id;

  const [quote, setQuote] = useState<Quotation | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [busy, setBusy] = useState(false);
  const [confirmArchive, setConfirmArchive] = useState(false);
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
        if (active) setError(e instanceof Error ? e.message : t("detail.loadError"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce, t]);

  /**
   * File this quote away, or bring it back. There is no delete: the quotation
   * number is a per-shop serial allocated at create time. The backend refuses
   * one the customer can still act on (REQUESTED / PENDING).
   *
   * Merchant-side only — the customer keeps seeing the quote in their list.
   *
   * Either way we return to the list, where a restored quote reappears and an
   * archived one has gone.
   */
  async function onSetArchived(archived: boolean) {
    setBusy(true);
    setActionError(null);
    try {
      await setQuotationArchived(id, archived);
      setConfirmArchive(false);
      router.push(BACK);
      router.refresh();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("detail.archiveError"));
      setBusy(false);
    }
  }

  async function onCancel() {
    setBusy(true);
    setActionError(null);
    try {
      await cancelQuotation(id);
      setConfirmCancel(false);
      setNonce((n) => n + 1);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : t("detail.cancelError"));
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
      setActionError(e instanceof Error ? e.message : t("detail.declineError"));
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
        <BackLink href={BACK} label={t("list.title")} />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? t("detail.notFound")}
        </p>
      </div>
    );
  }

  const isRequested = quote.status === "REQUESTED";
  const isPending = quote.status === "PENDING";
  const meta = isRequested
    ? t("detail.metaFrom", { party: quotationPartyName(quote), date: formatDateTime(quote.createdAt) })
    : t("detail.metaTo", { party: quotationPartyName(quote), date: formatDateTime(quote.createdAt) });

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label={t("list.title")} />

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
              {QUOTATION_STATUS_LABELS[quote.status] ? t(`status.${quote.status}`) : quote.status}
            </span>
          </div>
          <p className="mt-xs text-body-sm text-muted">{meta}</p>
          {quote.invoice ? (
            <Link
              href={`/dashboard/invoices/${quote.invoice.id}`}
              className="mt-sm inline-flex items-center gap-xs rounded-full bg-success-soft px-md py-xs text-body-sm font-semibold text-success transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-success-soft"
            >
              <ReceiptText size={14} /> {t("detail.invoiceBadge", { invoiceNo: quote.invoice.invoiceNo })}
            </Link>
          ) : null}
          {quote.status === "DECLINED" && quote.declineNote ? (
            <p className="mt-xs text-body-sm text-error">{t("detail.reason", { reason: quote.declineNote })}</p>
          ) : null}
        </div>
        <div className="flex shrink-0 flex-wrap items-center gap-sm">
          {/* A settled quote can be filed away; an archived one brought back.
              While the customer can still act, neither is offered — an accept
              landing against a quote the merchant can't see is nobody's job
              to chase. */}
          {quote.archivedAt ? (
            // Restoring needs no confirmation: it only puts the quote back.
            <button
              type="button"
              onClick={() => void onSetArchived(false)}
              disabled={busy}
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
            >
              <ArchiveRestore size={16} /> {t("actions.restore")}
            </button>
          ) : !isRequested && !isPending ? (
            <button
              type="button"
              onClick={() => setConfirmArchive(true)}
              disabled={busy}
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
            >
              <ArchiveDown size={16} /> {t("actions.archive")}
            </button>
          ) : null}
          <Link
            href={`/dashboard/reports?tab=calculator&quotation=${id}`}
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Calculator size={16} /> {t("detail.openInCalculator")}
          </Link>
          <a
            href={quotationPdfUrl(id)}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Download size={16} /> {t("detail.pdf")}
          </a>
        </div>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{actionError}</p>
      ) : null}

      {/* Items */}
      <Divider className="my-xl" />
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">
        {t("detail.itemsHeading", { count: quote.items.length })}
      </h2>
      {quote.items.map((it, i) => (
        <LineRow key={i} line={it} />
      ))}

      {/* Totals */}
      <div className="mt-xl ml-auto w-full max-w-form border-t border-hairline pt-md">
        <Row label={t("totals.subtotal")} value={quote.subtotal} />
        <Row label={t("totals.gst")} value={quote.taxAmount} />
        <div className="mt-sm flex items-center justify-between border-t border-hairline pt-sm">
          <span className="text-title-md text-ink">{t("totals.total")}</span>
          <span className="text-title-lg font-bold text-ink">{formatINR2(quote.total)}</span>
        </div>
      </div>

      {/* Note */}
      {quote.note ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">
            {isRequested ? t("detail.customerNote") : t("detail.note")}
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
            {t("actions.decline")}
          </button>
          <Link
            href={`/dashboard/quotations/${id}/respond`}
            className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong"
          >
            {t("actions.priceAndSend")}
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
            <XCircle size={16} /> {t("actions.cancel")}
          </button>
        </div>
      ) : null}

      {confirmArchive ? (
        <Modal title={t("archiveModal.title")} onClose={() => setConfirmArchive(false)}>
          <p className="text-body-md text-muted">{t("archiveModal.body")}</p>
          <ModalActions
            busy={busy}
            confirmLabel={t("actions.archive")}
            onCancel={() => setConfirmArchive(false)}
            onConfirm={() => void onSetArchived(true)}
          />
        </Modal>
      ) : null}

      {confirmCancel ? (
        <Modal title={t("cancelModal.title")} onClose={() => setConfirmCancel(false)}>
          <p className="text-body-md text-muted">{t("cancelModal.body")}</p>
          <ModalActions
            busy={busy}
            danger
            confirmLabel={t("actions.cancel")}
            onCancel={() => setConfirmCancel(false)}
            onConfirm={onCancel}
          />
        </Modal>
      ) : null}
      {declineOpen ? (
        <Modal title={t("declineModal.title")} onClose={() => setDeclineOpen(false)}>
          <p className="text-body-md text-muted">{t("declineModal.body")}</p>
          <TextAreaField label={t("declineModal.reasonLabel")} value={declineNote} onChange={setDeclineNote} rows={2} />
          <ModalActions
            busy={busy}
            danger
            confirmLabel={t("actions.decline")}
            onCancel={() => setDeclineOpen(false)}
            onConfirm={onDecline}
          />
        </Modal>
      ) : null}
    </div>
  );
}

function LineRow({ line }: { line: QuotationLine }) {
  const t = useTranslations("quotations");
  const total = line.lineTotal ?? line.quantity * line.unitPrice * (1 + line.taxPercent / 100);
  return (
    <div className="flex items-start gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{line.name ?? t("line.productFallback")}</p>
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
