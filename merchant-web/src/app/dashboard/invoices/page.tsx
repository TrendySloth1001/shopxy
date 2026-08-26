"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import {
  Archive,
  ArrowDownLeft,
  ArrowUpRight,
  Download,
  Plus,
  ReceiptText,
  RefreshCw,
  Search,
  X,
} from "@/shared/icons";
import { PageHeader } from "@/shared/ui/page-header";
import { SelectField } from "@/shared/ui/form";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import { invoicePdfUrl, listInvoices } from "@/features/invoices/api";
import { getVendor } from "@/features/vendors/api";
import { getParty } from "@/features/parties/api";
import {
  counterpartyName,
  invoiceItemCount,
  isSale,
  type Invoice,
} from "@/features/invoices/schema";
import { INVOICE_STATUS_CLASSES } from "@/features/invoices/format";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

const TYPE_TABS: { key: string; labelKey: string }[] = [
  { key: "", labelKey: "list.typeAll" },
  { key: "SALE", labelKey: "list.typeSales" },
  { key: "PURCHASE", labelKey: "list.typePurchases" },
];

const STATUS_OPTION_KEYS: { value: string; labelKey: string }[] = [
  { value: "", labelKey: "list.statusAny" },
  { value: "DRAFT", labelKey: "status.draft" },
  { value: "CONFIRMED", labelKey: "status.confirmed" },
  { value: "CANCELLED", labelKey: "status.cancelled" },
];

const DOC_OPTION_VALUES = [
  "TAX_INVOICE",
  "BILL_OF_SUPPLY",
  "ESTIMATE",
  "PROFORMA",
  "CREDIT_NOTE",
  "DEBIT_NOTE",
];

export default function InvoicesPage() {
  return (
    <Suspense fallback={null}>
      <InvoicesPageInner />
    </Suspense>
  );
}

function InvoicesPageInner() {
  const t = useTranslations("invoices");
  const searchParams = useSearchParams();
  const statusOptions = STATUS_OPTION_KEYS.map((o) => ({ value: o.value, label: t(o.labelKey) }));
  const docOptions = [
    { value: "", label: t("list.docAll") },
    ...DOC_OPTION_VALUES.map((d) => ({ value: d, label: t(`docType.${d}`) })),
  ];
  const vendorId = toId(searchParams.get("vendorId"));
  const partyId = toId(searchParams.get("partyId"));

  const [rows, setRows] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [type, setType] = useState(() => normalizeType(searchParams.get("type")));
  const [status, setStatus] = useState("");
  const [documentType, setDocumentType] = useState("");
  const [scopeName, setScopeName] = useState<string | null>(null);

  useEffect(() => {
    const t = setTimeout(() => setSearch(searchInput.trim()), 300);
    return () => clearTimeout(t);
  }, [searchInput]);

  useEffect(() => {
    if (!vendorId && !partyId) return;
    let active = true;
    void (async () => {
      try {
        const entity = vendorId ? await getVendor(vendorId) : await getParty(partyId!);
        if (active) setScopeName(entity.name);
      } catch {
        if (active) setScopeName(null);
      }
    })();
    return () => {
      active = false;
    };
  }, [vendorId, partyId]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listInvoices({ type, status, documentType, search, vendorId, partyId });
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
  }, [nonce, type, status, documentType, search, vendorId, partyId, t]);

  const scoped = vendorId != null || partyId != null;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={ReceiptText}
        title={t("list.title")}
        subtitle={t("list.subtitle")}
      >
        <button
          type="button"
          onClick={() => setNonce((n) => n + 1)}
          disabled={loading}
          aria-label={t("list.refresh")}
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <Link
          href="/dashboard/invoices/archived"
          className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          <Archive size={16} /> {t("actions.archived")}
        </Link>
        <MaybeLocked area="invoices" label={t("docType.ESTIMATE")}>
          <Link
            href="/dashboard/invoices/new?doc=ESTIMATE"
            className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            {t("docType.ESTIMATE")}
          </Link>
        </MaybeLocked>
        <MaybeLocked area="invoices" label={t("docType.PROFORMA")}>
          <Link
            href="/dashboard/invoices/new?doc=PROFORMA"
            className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            {t("docType.PROFORMA")}
          </Link>
        </MaybeLocked>
        <MaybeLocked area="invoices" label={t("actions.newInvoice")}>
          <Link
            href="/dashboard/invoices/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> {t("actions.newInvoice")}
          </Link>
        </MaybeLocked>
      </PageHeader>

      {scoped ? (
        <div className="mt-lg flex flex-wrap items-center gap-sm rounded-md bg-brand-soft px-md py-sm text-body-sm text-brand-strong">
          <span>
            {vendorId ? t("scope.showingBills") : t("scope.showingInvoices")}{" "}
            <span className="font-semibold">{scopeName ?? t("scope.thisContact")}</span>
          </span>
          <Link
            href="/dashboard/invoices"
            className="inline-flex items-center gap-xs rounded-button px-sm py-px text-label-md text-brand-strong underline-offset-2 transition-colors hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <X size={14} /> {t("scope.clearFilter")}
          </Link>
        </div>
      ) : null}

      <div className="mt-xl flex items-center gap-sm rounded-input border border-hairline bg-field px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
        <Search size={16} className="shrink-0 text-subtle" />
        <input
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          placeholder={t("list.searchPlaceholder")}
          className="h-10 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
        />
      </div>

      <div className="mt-md flex flex-wrap items-end gap-md">
        <div className="flex flex-wrap items-center gap-sm">
          {TYPE_TABS.map((tab) => (
            <button
              key={tab.key}
              type="button"
              onClick={() => setType(tab.key)}
              className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
                type === tab.key ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
              }`}
            >
              {t(tab.labelKey)}
            </button>
          ))}
        </div>
        <div className="min-w-40 flex-1 sm:max-w-48">
          <SelectField label={t("list.statusLabel")} value={status} onChange={setStatus} options={statusOptions} />
        </div>
        <div className="min-w-40 flex-1 sm:max-w-56">
          <SelectField label={t("list.documentLabel")} value={documentType} onChange={setDocumentType} options={docOptions} />
        </div>
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-lg">
        {!loading && rows.length > 0 ? (
          <p className="mb-sm text-body-sm text-muted">
            {rows.length} {rows.length === 1 ? t("list.countOne") : t("list.countOther")}
          </p>
        ) : null}
        {loading ? (
          <ListRowsSkeleton />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand-strong">
              <ReceiptText size={22} />
            </span>
            <p className="text-body-md text-muted">{t("list.empty")}</p>
            <MaybeLocked area="invoices" label={t("actions.newInvoice")}>
              <Link
                href="/dashboard/invoices/new"
                className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
              >
                <Plus size={16} /> {t("actions.newInvoice")}
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

function toId(raw: string | null): string | undefined {
  const trimmed = raw?.trim();
  return trimmed ? trimmed : undefined;
}

function normalizeType(raw: string | null): string {
  return raw === "SALE" || raw === "PURCHASE" ? raw : "";
}

function statusLabel(t: ReturnType<typeof useTranslations>, status: string): string {
  const key = { DRAFT: "status.draft", CONFIRMED: "status.confirmed", CANCELLED: "status.cancelled" }[status];
  return key ? t(key) : status;
}

function InvoiceRow({ invoice }: { invoice: Invoice }) {
  const t = useTranslations("invoices");
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
              {statusLabel(t, invoice.status)}
            </span>
          </div>
          <p className="truncate text-body-sm text-muted">{counterpartyName(invoice)}</p>
          <p className="text-body-sm text-subtle">
            {formatDateTime(invoice.invoiceDate)} · {items} {items === 1 ? t("list.itemOne") : t("list.itemOther")}
          </p>
        </div>
      </Link>
      <div className="flex shrink-0 items-center gap-sm">
        <span className="text-body-md font-semibold text-ink">{formatINR2(invoice.total)}</span>
        <a
          href={invoicePdfUrl(invoice.id)}
          target="_blank"
          rel="noopener noreferrer"
          aria-label={t("list.openPdf")}
          className="inline-flex size-9 items-center justify-center rounded-button text-muted transition-colors hover:bg-surface-tint hover:text-ink"
        >
          <Download size={16} />
        </a>
      </div>
    </div>
  );
}
