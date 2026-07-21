"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { ChevronRight, FileText, Plus, RefreshCw } from "@/shared/icons";
import { PageHeader } from "@/shared/ui/page-header";
import { formatDateTime } from "@/shared/datetime";
import { formatINR2 } from "@/shared/money";
import { listQuotations } from "@/features/quotations/api";
import {
  QUOTATION_STATUS_CLASSES,
  QUOTATION_STATUS_LABELS,
  quotationPartyName,
  type Quotation,
} from "@/features/quotations/schema";
import { MaybeLocked } from "@/features/auth/components/maybe-locked";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";

const TABS: { key: string; labelKey: string }[] = [
  { key: "", labelKey: "tabs.all" },
  { key: "REQUESTED", labelKey: "tabs.requested" },
  { key: "PENDING", labelKey: "tabs.sent" },
  { key: "ACCEPTED", labelKey: "tabs.accepted" },
];

export default function QuotationsPage() {
  const t = useTranslations("quotations");
  const [rows, setRows] = useState<Quotation[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState("");
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await listQuotations(status ? { status } : undefined);
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
  }, [status, nonce, t]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={FileText}
        tone="teal"
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
        <MaybeLocked area="invoices" label={t("actions.new")}>
          <Link
            href="/dashboard/quotations/new"
            className="inline-flex h-10 items-center gap-sm rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <Plus size={16} /> {t("actions.new")}
          </Link>
        </MaybeLocked>
      </PageHeader>

      <div className="mt-xl flex flex-wrap items-center gap-sm">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setStatus(tab.key)}
            className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
              status === tab.key ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
            }`}
          >
            {t(tab.labelKey)}
          </button>
        ))}
      </div>

      {error ? (
        <p className="mt-md rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-lg">
        {loading ? (
          <ListRowsSkeleton />
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center gap-md py-xxxl text-center">
            <span className="flex size-12 items-center justify-center rounded-full bg-accent-teal-soft text-accent-teal">
              <FileText size={22} />
            </span>
            <p className="text-body-md text-muted">{t("list.empty")}</p>
            <MaybeLocked area="invoices" label={t("actions.new")}>
              <Link
                href="/dashboard/quotations/new"
                className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
              >
                <Plus size={16} /> {t("actions.new")}
              </Link>
            </MaybeLocked>
          </div>
        ) : (
          rows.map((q) => <QuotationRow key={q.id} quotation={q} />)
        )}
      </div>
    </div>
  );
}

function QuotationRow({ quotation }: { quotation: Quotation }) {
  const t = useTranslations("quotations");
  const items = quotation.items.length;
  return (
    <Link
      href={`/dashboard/quotations/${quotation.id}`}
      className="flex items-center gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint"
    >
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-sm">
          <span className="truncate text-body-md text-ink">{quotation.quotationNo}</span>
          <span
            className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold ${
              QUOTATION_STATUS_CLASSES[quotation.status] ?? "bg-surface-tint text-muted"
            }`}
          >
            {QUOTATION_STATUS_LABELS[quotation.status]
              ? t(`status.${quotation.status}`)
              : quotation.status}
          </span>
        </div>
        <p className="truncate text-body-sm text-muted">{quotationPartyName(quotation)}</p>
        <p className="text-body-sm text-subtle">
          {formatDateTime(quotation.createdAt)} · {items} {items === 1 ? t("list.itemOne") : t("list.itemMany")}
        </p>
      </div>
      <span className="shrink-0 text-body-md font-semibold text-ink">{formatINR2(quotation.total)}</span>
      <ChevronRight size={18} className="shrink-0 text-subtle" />
    </Link>
  );
}
