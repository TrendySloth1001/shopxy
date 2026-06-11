"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  ArrowDownLeft,
  ArrowUpRight,
  Download,
  Plus,
  ReceiptText,
  RefreshCw,
  Search,
} from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { SelectField } from "@/shared/ui/form";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import { invoicePdfUrl, listInvoices } from "@/features/invoices/api";
import {
  DOCUMENT_TYPE_LABELS,
  counterpartyName,
  invoiceItemCount,
  isSale,
  type Invoice,
} from "@/features/invoices/schema";
import { INVOICE_STATUS_CLASSES, INVOICE_STATUS_LABELS } from "@/features/invoices/format";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

const TYPE_TABS: { key: string; label: string }[] = [
  { key: "", label: "All" },
  { key: "SALE", label: "Sales" },
  { key: "PURCHASE", label: "Purchases" },
];

const STATUS_OPTIONS = [
  { value: "", label: "Any status" },
  { value: "DRAFT", label: "Draft" },
  { value: "CONFIRMED", label: "Confirmed" },
  { value: "CANCELLED", label: "Cancelled" },
];

const DOC_OPTIONS = [
  { value: "", label: "All documents" },
  ...["TAX_INVOICE", "BILL_OF_SUPPLY", "ESTIMATE", "PROFORMA", "CREDIT_NOTE", "DEBIT_NOTE"].map((d) => ({
    value: d,
    label: DOCUMENT_TYPE_LABELS[d],
  })),
];

export default function InvoicesPage() {
  const [rows, setRows] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [type, setType] = useState("");
  const [status, setStatus] = useState("");
  const [documentType, setDocumentType] = useState("");

  useEffect(() => {
    const t = setTimeout(() => setSearch(searchInput.trim()), 300);
    return () => clearTimeout(t);
  }, [searchInput]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listInvoices({ type, status, documentType, search });
        if (!active) return;
        setRows(data);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load invoices.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce, type, status, documentType, search]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={ReceiptText}
        title="Invoices"
        subtitle="Sales and purchase invoices. Save drafts, confirm to post stock, share the GST PDF and record payments."
      >
        <button
          type="button"
          onClick={() => setNonce((n) => n + 1)}
          disabled={loading}
          aria-label="Refresh"
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <MaybeLocked area="invoices" label="Estimate">
          <Link
            href="/dashboard/invoices/new?doc=ESTIMATE"
            className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            Estimate
          </Link>
        </MaybeLocked>
        <MaybeLocked area="invoices" label="Proforma">
          <Link
            href="/dashboard/invoices/new?doc=PROFORMA"
            className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            Proforma
          </Link>
        </MaybeLocked>
        <MaybeLocked area="invoices" label="New invoice">
          <Link
            href="/dashboard/invoices/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> New invoice
          </Link>
        </MaybeLocked>
      </PageHeader>

      {/* Search */}
      <div className="mt-xl flex items-center gap-sm rounded-input border border-hairline bg-white px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
        <Search size={16} className="shrink-0 text-subtle" />
        <input
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          placeholder="Search invoice no, customer or vendor"
          className="h-10 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
        />
      </div>

      {/* Filters */}
      <div className="mt-md flex flex-wrap items-end gap-md">
        <div className="flex flex-wrap items-center gap-sm">
          {TYPE_TABS.map((t) => (
            <button
              key={t.key}
              type="button"
              onClick={() => setType(t.key)}
              className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
                type === t.key ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
        <div className="min-w-40 flex-1 sm:max-w-48">
          <SelectField label="Status" value={status} onChange={setStatus} options={STATUS_OPTIONS} />
        </div>
        <div className="min-w-40 flex-1 sm:max-w-56">
          <SelectField label="Document" value={documentType} onChange={setDocumentType} options={DOC_OPTIONS} />
        </div>
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-lg">
        {!loading && rows.length > 0 ? (
          <p className="mb-sm text-body-sm text-muted">
            {rows.length} {rows.length === 1 ? "invoice" : "invoices"}
          </p>
        ) : null}
        {loading ? (
          <ListRowsSkeleton />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand-strong">
              <ReceiptText size={22} />
            </span>
            <p className="text-body-md text-muted">No invoices match these filters.</p>
            <MaybeLocked area="invoices" label="New invoice">
              <Link
                href="/dashboard/invoices/new"
                className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
              >
                <Plus size={16} /> New invoice
              </Link>
            </MaybeLocked>
          </div>
        ) : (
          rows.map((inv) => <InvoiceRow key={inv.id} invoice={inv} />)
        )}
      </div>
    </div>
  );
}

function InvoiceRow({ invoice }: { invoice: Invoice }) {
  const sale = isSale(invoice);
  const items = invoiceItemCount(invoice);
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <Link href={`/dashboard/invoices/${invoice.id}`} className="flex min-w-0 flex-1 items-center gap-md">
        <span
          className={`flex size-10 shrink-0 items-center justify-center rounded-full ${
            sale ? "bg-success-soft text-success" : "bg-accent-indigo-soft text-accent-indigo"
          }`}
        >
          {sale ? <ArrowUpRight size={18} /> : <ArrowDownLeft size={18} />}
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-sm">
            <span className="truncate text-body-md text-ink">{invoice.invoiceNo}</span>
            <span
              className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
                INVOICE_STATUS_CLASSES[invoice.status] ?? "bg-surface-tint text-muted"
              }`}
            >
              {INVOICE_STATUS_LABELS[invoice.status] ?? invoice.status}
            </span>
          </div>
          <p className="truncate text-body-sm text-muted">{counterpartyName(invoice)}</p>
          <p className="text-body-sm text-subtle">
            {formatDateTime(invoice.invoiceDate)} · {items} {items === 1 ? "item" : "items"}
          </p>
        </div>
      </Link>
      <div className="flex shrink-0 items-center gap-sm">
        <span className="text-body-md font-semibold text-ink">{formatINR2(invoice.total)}</span>
        <a
          href={invoicePdfUrl(invoice.id)}
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Open PDF"
          className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
        >
          <Download size={16} />
        </a>
      </div>
    </div>
  );
}
