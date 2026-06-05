"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowDownLeft,
  ArrowUpRight,
  BadgeIndianRupee,
  Download,
  FileUp,
  Landmark,
  MapPin,
  Pencil,
  Phone,
  Trash2,
  Wallet,
} from "lucide-react";
import { BackLink } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { Modal, ModalActions } from "@/shared/ui/modal";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import { RecordPaymentModal } from "@/features/payments/record-payment-modal";
import { listPayments } from "@/features/payments/api";
import { PAYMENT_MODE_LABELS, type Payment } from "@/features/payments/schema";
import {
  convertEstimate,
  deleteInvoice,
  getInvoice,
  invoicePdfUrl,
  updateInvoiceStatus,
} from "@/features/invoices/api";
import {
  DOCUMENT_TYPE_LABELS,
  counterpartyName,
  isSale,
  type Invoice,
  type InvoiceItem,
} from "@/features/invoices/schema";
import {
  INVOICE_STATUS_CLASSES,
  INVOICE_STATUS_LABELS,
  gstTypeLabel,
} from "@/features/invoices/format";
import { DetailSkeleton } from "@/shared/ui/skeleton";

const BACK = "/dashboard/invoices";

export default function InvoiceDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const id = Number(params.id);

  const [invoice, setInvoice] = useState<Invoice | null>(null);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const reload = () => setNonce((n) => n + 1);

  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [confirmCancel, setConfirmCancel] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [payOpen, setPayOpen] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const inv = await getInvoice(id);
        const pays = inv.status === "CONFIRMED" ? await listPayments({ invoiceId: id }).catch(() => []) : [];
        if (!active) return;
        setInvoice(inv);
        setPayments(pays);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load the invoice.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id, nonce]);

  async function setStatus(status: "CONFIRMED" | "CANCELLED") {
    setBusy(true);
    setActionError(null);
    try {
      await updateInvoiceStatus(id, status);
      setConfirmCancel(false);
      reload();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not update the invoice.");
    } finally {
      setBusy(false);
    }
  }

  async function onDelete() {
    setBusy(true);
    setActionError(null);
    try {
      await deleteInvoice(id);
      router.push(BACK);
      router.refresh();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not delete the invoice.");
      setBusy(false);
    }
  }

  async function onConvert() {
    setBusy(true);
    setActionError(null);
    try {
      const created = await convertEstimate(id);
      router.push(`/dashboard/invoices/${created.id}`);
      router.refresh();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Could not convert to an invoice.");
      setBusy(false);
    }
  }

  if (loading) {
    return <DetailSkeleton />;
  }
  if (error || !invoice) {
    return (
      <div className="w-full px-lg py-xxl md:px-xxl">
        <BackLink href={BACK} label="Invoices" />
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error ?? "Invoice not found."}
        </p>
      </div>
    );
  }

  const sale = isSale(invoice);
  const isDraft = invoice.status === "DRAFT";
  const isConfirmed = invoice.status === "CONFIRMED";
  const isEstimate = invoice.documentType === "ESTIMATE" || invoice.documentType === "PROFORMA";
  const received = payments.filter((p) => !p.voidedAt).reduce((sum, p) => sum + p.amount, 0);
  const outstanding = Math.max(0, invoice.total - received);
  const hasCounterparty = sale ? invoice.partyId != null : invoice.vendorId != null;
  const canRecordPayment = isConfirmed && hasCounterparty && outstanding > 0.005;

  return (
    <div className="w-full px-lg py-xxl pb-massive md:px-xxl">
      <BackLink href={BACK} label="Invoices" />

      {/* Header */}
      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div className="flex min-w-0 items-start gap-md">
          <span
            className={`flex size-12 shrink-0 items-center justify-center rounded-lg ${
              sale ? "bg-success-soft text-success" : "bg-accent-indigo-soft text-accent-indigo"
            }`}
          >
            {sale ? <ArrowUpRight size={24} /> : <ArrowDownLeft size={24} />}
          </span>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-sm">
              <h1 className="text-headline-md text-ink">{invoice.invoiceNo}</h1>
              <span
                className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
                  INVOICE_STATUS_CLASSES[invoice.status] ?? "bg-surface-tint text-muted"
                }`}
              >
                {INVOICE_STATUS_LABELS[invoice.status] ?? invoice.status}
              </span>
            </div>
            <p className="mt-xs flex flex-wrap items-center gap-sm text-body-sm text-muted">
              <span>{sale ? "Sale" : "Purchase"}</span>
              <span className="text-subtle">·</span>
              <span>{DOCUMENT_TYPE_LABELS[invoice.documentType] ?? invoice.documentType}</span>
              <span className="text-subtle">·</span>
              <span>{gstTypeLabel(invoice)}</span>
              <span className="text-subtle">·</span>
              <span>{formatDateTime(invoice.invoiceDate)}</span>
            </p>
          </div>
        </div>

        <div className="flex shrink-0 flex-wrap items-center gap-sm">
          {isDraft ? (
            <Link
              href={`/dashboard/invoices/${id}/edit`}
              className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
            >
              <Pencil size={16} /> Edit
            </Link>
          ) : null}
          <a
            href={invoicePdfUrl(id)}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            <Download size={16} /> PDF
          </a>
          {canRecordPayment ? (
            <button
              type="button"
              onClick={() => setPayOpen(true)}
              className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong"
            >
              <Wallet size={16} /> Mark as paid
            </button>
          ) : null}
          {isEstimate && invoice.status !== "CANCELLED" ? (
            <button
              type="button"
              onClick={onConvert}
              disabled={busy}
              className="inline-flex h-10 items-center gap-sm rounded-button bg-accent-indigo px-md text-label-md text-white transition-colors hover:opacity-90 disabled:opacity-60"
            >
              <FileUp size={16} /> Convert to invoice
            </button>
          ) : null}
          {invoice.status !== "CONFIRMED" ? (
            <button
              type="button"
              onClick={() => setConfirmDelete(true)}
              aria-label="Delete"
              className="inline-flex size-10 items-center justify-center rounded-button text-muted transition-colors hover:bg-error-soft hover:text-error"
            >
              <Trash2 size={16} />
            </button>
          ) : null}
        </div>
      </div>

      {actionError ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{actionError}</p>
      ) : null}

      {/* Counterparty */}
      <CounterpartyBlock invoice={invoice} sale={sale} />

      {/* Items */}
      <Divider className="my-xl" />
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Items</h2>
      {invoice.items.map((it, i) => (
        <ItemRow key={it.id ?? i} item={it} />
      ))}

      {/* Totals */}
      <div className="mt-xl ml-auto w-full max-w-form border-t border-hairline pt-md">
        <TotalRow label="Subtotal" value={invoice.subtotal} />
        {invoice.discount > 0 ? <TotalRow label="Discount" value={-invoice.discount} /> : null}
        {invoice.isInterstate ? (
          <TotalRow label="IGST" value={invoice.igstAmount} />
        ) : (
          <>
            <TotalRow label="CGST" value={invoice.cgstAmount} />
            <TotalRow label="SGST" value={invoice.sgstAmount} />
          </>
        )}
        {invoice.cessAmount > 0 ? <TotalRow label="Cess" value={invoice.cessAmount} /> : null}
        {Math.abs(invoice.roundOff) >= 0.005 ? <TotalRow label="Round-off" value={invoice.roundOff} /> : null}
        <div className="mt-sm flex items-center justify-between border-t border-hairline pt-sm">
          <span className="text-title-md text-ink">Total</span>
          <span className="text-title-lg font-bold text-ink">{formatINR2(invoice.total)}</span>
        </div>

        {isConfirmed ? (
          <>
            <div className="mt-sm border-t border-hairline pt-sm">
              <TotalRow label="Received" value={received} />
              <div className="flex items-center justify-between py-xs">
                <span className="text-body-md text-muted">Outstanding</span>
                <span
                  className={`text-body-md font-bold tabular-nums ${
                    outstanding > 0.005 ? "text-error" : "text-success"
                  }`}
                >
                  {formatINR2(outstanding)}
                </span>
              </div>
            </div>
          </>
        ) : null}
      </div>

      {invoice.amountInWords ? (
        <p className="mt-md text-body-sm italic text-muted">{invoice.amountInWords}</p>
      ) : null}

      {/* Payments */}
      {isConfirmed && payments.filter((p) => !p.voidedAt).length > 0 ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Payments</h2>
          {payments
            .filter((p) => !p.voidedAt)
            .map((p) => (
              <PaymentRow key={p.id} payment={p} />
            ))}
        </>
      ) : null}

      {/* Note */}
      {invoice.note ? (
        <>
          <Divider className="my-xl" />
          <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Note</h2>
          <p className="text-body-md text-muted">{invoice.note}</p>
        </>
      ) : null}

      {/* Draft action bar */}
      {isDraft ? (
        <div className="mt-xxl flex flex-wrap items-center gap-sm">
          <button
            type="button"
            onClick={() => setConfirmCancel(true)}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-error transition-colors hover:bg-error-soft disabled:text-disabled"
          >
            Cancel invoice
          </button>
          <button
            type="button"
            onClick={() => setStatus("CONFIRMED")}
            disabled={busy}
            className="inline-flex h-11 items-center gap-sm rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
          >
            {busy ? "Working…" : "Confirm invoice"}
          </button>
        </div>
      ) : null}

      {/* Modals */}
      {confirmCancel ? (
        <Modal title="Cancel this invoice?" onClose={() => setConfirmCancel(false)}>
          <p className="text-body-md text-muted">
            The draft is voided. Stock isn&rsquo;t affected because it was never posted.
          </p>
          <ModalActions
            busy={busy}
            danger
            confirmLabel="Cancel invoice"
            onCancel={() => setConfirmCancel(false)}
            onConfirm={() => setStatus("CANCELLED")}
          />
        </Modal>
      ) : null}
      {confirmDelete ? (
        <Modal title="Delete this invoice?" onClose={() => setConfirmDelete(false)}>
          <p className="text-body-md text-muted">
            Permanently removes this draft. This can&rsquo;t be undone.
          </p>
          <ModalActions
            busy={busy}
            danger
            confirmLabel="Delete"
            onCancel={() => setConfirmDelete(false)}
            onConfirm={onDelete}
          />
        </Modal>
      ) : null}
      {payOpen ? (
        <RecordPaymentModal
          kind={sale ? "RECEIPT" : "PAYMENT"}
          partyId={sale ? invoice.partyId ?? undefined : undefined}
          vendorId={sale ? undefined : invoice.vendorId ?? undefined}
          invoiceId={id}
          max={outstanding}
          onClose={() => setPayOpen(false)}
          onDone={() => {
            setPayOpen(false);
            reload();
          }}
        />
      ) : null}
    </div>
  );
}

function CounterpartyBlock({ invoice, sale }: { invoice: Invoice; sale: boolean }) {
  const name = counterpartyName(invoice);
  const phone = sale ? invoice.customerPhone : invoice.vendorPhone;
  const gstin = sale ? invoice.customerGstin : invoice.vendorGstin;
  const pan = sale ? invoice.customerPanNumber : invoice.vendorPanNumber;
  const address = [
    sale ? invoice.customerAddress : invoice.vendorAddress,
    sale ? invoice.customerCity : invoice.vendorCity,
    sale ? invoice.customerState : invoice.vendorState,
    sale ? invoice.customerPinCode : invoice.vendorPinCode,
  ]
    .filter(Boolean)
    .join(", ");

  return (
    <div className="mt-xl">
      <p className="text-label-md uppercase tracking-wide text-subtle">{sale ? "Bill to" : "Supplier"}</p>
      <p className="mt-xs text-title-md text-ink">{name}</p>
      <div className="mt-sm flex flex-col gap-xs">
        {phone ? <Row icon={<Phone size={14} />} text={phone} /> : null}
        {address ? <Row icon={<MapPin size={14} />} text={address} /> : null}
        {gstin ? <Row icon={<Landmark size={14} />} text={`GSTIN ${gstin}`} /> : null}
        {pan ? <Row icon={<BadgeIndianRupee size={14} />} text={`PAN ${pan}`} /> : null}
      </div>
    </div>
  );
}

function Row({ icon, text }: { icon: React.ReactNode; text: string }) {
  return (
    <p className="flex items-center gap-sm text-body-sm text-muted">
      <span className="text-subtle">{icon}</span>
      {text}
    </p>
  );
}

function ItemRow({ item }: { item: InvoiceItem }) {
  return (
    <div className="flex items-start gap-md border-b border-hairline py-md">
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{item.productName ?? "Product"}</p>
        <p className="text-body-sm text-muted">
          {item.quantity} {item.unit ?? ""} × {formatINR2(item.unitPrice)}
          {item.taxPercent > 0 ? ` · ${item.taxPercent}% GST` : ""}
        </p>
      </div>
      <span className="shrink-0 text-body-md font-semibold text-ink">{formatINR2(item.total)}</span>
    </div>
  );
}

function PaymentRow({ payment }: { payment: Payment }) {
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-success-soft text-success">
        <Wallet size={16} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">
          {PAYMENT_MODE_LABELS[payment.mode] ?? payment.mode}
          {payment.referenceNo ? ` · ${payment.referenceNo}` : ""}
        </p>
        <p className="text-body-sm text-muted">
          {formatDateTime(payment.paymentDate)}
          {payment.modeReference ? ` · ${payment.modeReference}` : ""}
        </p>
      </div>
      <span className="shrink-0 text-body-md font-semibold text-success">+{formatINR2(payment.amount)}</span>
    </div>
  );
}

function TotalRow({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center justify-between py-xs">
      <span className="text-body-md text-muted">{label}</span>
      <span className="text-body-md tabular-nums text-ink">{formatINR2(value)}</span>
    </div>
  );
}
