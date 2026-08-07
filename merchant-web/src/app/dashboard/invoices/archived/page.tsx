"use client";

import { Fragment, useEffect, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import {
  Archive,
  ArchiveRestore,
  ArrowUpRight,
  ArrowDownLeft,
  RefreshCw,
} from "@/shared/icons";
import { PageHeader } from "@/shared/ui/page-header";
import { DayDivider } from "@/shared/ui/day-divider";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";
import { isSameDay } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import { listInvoices, setInvoiceArchived } from "@/features/invoices/api";
import {
  counterpartyName,
  isSale,
  type Invoice,
} from "@/features/invoices/schema";

// Same primary axis the invoices list filters on — direction of money.
// "" is All. Labels come from the message catalog at render time.
const TYPE_TABS: { key: string; labelKey: string }[] = [
  { key: "", labelKey: "list.typeAll" },
  { key: "SALE", labelKey: "list.typeSales" },
  { key: "PURCHASE", labelKey: "list.typePurchases" },
];

/**
 * Documents the merchant filed out of the working list.
 *
 * They are not deleted and cannot be: the serial is allocated at create time
 * and Rule 46(b) needs the run consecutive, so every archived row still holds
 * its number. This page is the way back.
 */
export default function ArchivedInvoicesPage() {
  const t = useTranslations("invoices");
  const [rows, setRows] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [restoring, setRestoring] = useState<string | null>(null);
  const [type, setType] = useState("");
  const [nonce, setNonce] = useState(0);

  // Same shape as the main invoices list: the fetch runs inside an async IIFE
  // so no setState happens synchronously in the effect body, and `active`
  // guards against a response landing after unmount.
  //
  // The type filter goes to the server rather than being applied over the
  // loaded page, so it still means something past the fetch limit.
  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listInvoices({ archived: true, type: type || undefined });
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
  }, [nonce, type, t]);

  async function onRestore(invoice: Invoice) {
    setRestoring(invoice.id);
    setError(null);
    try {
      await setInvoiceArchived(invoice.id, false);
      setRows((prev) => prev.filter((r) => r.id !== invoice.id));
    } catch (e) {
      setError(e instanceof Error ? e.message : t("detail.archiveError"));
    } finally {
      setRestoring(null);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={Archive}
        title={t("archived.title")}
        subtitle={t("archived.subtitle")}
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
          href="/dashboard/invoices"
          className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          {t("archived.backToList")}
        </Link>
      </PageHeader>

      <div className="mt-xl flex flex-wrap items-center gap-sm">
        {TYPE_TABS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setType(tab.key)}
            className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
              type === tab.key
                ? "bg-brand text-white"
                : "border border-hairline text-ink hover:bg-surface-tint"
            }`}
          >
            {t(tab.labelKey)}
          </button>
        ))}
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
          {error}
        </p>
      ) : null}

      <div className="mt-lg">
        {loading ? (
          <ListRowsSkeleton />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-brand-soft text-brand-strong">
              <Archive size={22} />
            </span>
            <p className="text-body-md text-muted">{t("archived.empty")}</p>
            <p className="max-w-content text-body-sm text-subtle">
              {t("archived.emptyHint")}
            </p>
          </div>
        ) : (
          rows.map((invoice, i) => {
            const date = new Date(invoice.invoiceDate);
            // Grouped by invoiceDate, matching the server's ordering — group
            // by anything the list isn't sorted on and a heading repeats
            // further down the scroll.
            const newDay =
              i === 0 || !isSameDay(date, new Date(rows[i - 1].invoiceDate));
            return (
              <Fragment key={invoice.id}>
                {newDay ? <DayDivider date={date} /> : null}
                <ArchivedRow
                  invoice={invoice}
                  busy={restoring === invoice.id}
                  onRestore={() => void onRestore(invoice)}
                />
              </Fragment>
            );
          })
        )}
      </div>
    </div>
  );
}

function ArchivedRow({
  invoice,
  busy,
  onRestore,
}: {
  invoice: Invoice;
  busy: boolean;
  onRestore: () => void;
}) {
  const t = useTranslations("invoices");
  const sale = isSale(invoice);
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <Link
        href={`/dashboard/invoices/${invoice.id}`}
        className="flex min-w-0 flex-1 items-center gap-md"
      >
        <span
          className={`flex size-10 shrink-0 items-center justify-center rounded-full ${
            sale ? "bg-success-soft text-success" : "bg-accent-indigo-soft text-accent-indigo"
          }`}
        >
          {sale ? <ArrowUpRight size={18} /> : <ArrowDownLeft size={18} />}
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-sm">
            {/* The number is the point: it stays allocated, which is what
                makes archiving legal where deleting wasn't. */}
            <span className="truncate text-body-md text-ink">{invoice.invoiceNo}</span>
            <span className="inline-flex items-center rounded-full bg-hero-panel px-sm py-px text-body-sm font-semibold text-muted">
              {invoice.status}
            </span>
          </div>
          <p className="truncate text-body-sm text-muted">{counterpartyName(invoice)}</p>
        </div>
      </Link>
      <span className="shrink-0 text-body-md text-ink">
        {formatINR2(invoice.total)}
      </span>
      <button
        type="button"
        onClick={onRestore}
        disabled={busy}
        className="inline-flex h-9 shrink-0 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
      >
        <ArchiveRestore size={16} />
        {busy ? t("archived.restoring") : t("archived.restore")}
      </button>
    </div>
  );
}
