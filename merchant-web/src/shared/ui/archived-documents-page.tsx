"use client";

import { Fragment, useEffect, useState, type ReactNode } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { Archive, ArchiveRestore, RefreshCw } from "@/shared/icons";
import { PageHeader } from "@/shared/ui/page-header";
import { DayDivider } from "@/shared/ui/day-divider";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";
import { isSameDay } from "@/shared/datetime";

export type ArchivedFilter = { key: string; label: string };

export type ArchivedRowData = {
  href: string;
  number: string;
  status: string;
  subtitle: string;
  trailing?: string;
  leading?: ReactNode;
};

export function ArchivedDocumentsPage<T>({
  title,
  subtitle,
  backHref,
  backLabel,
  emptyTitle,
  emptyBody,
  filters = [],
  load,
  restore,
  rowOf,
  dateOf,
  keyOf,
}: {
  title: string;
  subtitle: string;
  backHref: string;
  backLabel: string;
  emptyTitle: string;
  emptyBody: string;
  filters?: ArchivedFilter[];
  load: (filter: string) => Promise<T[]>;
  restore: (item: T) => Promise<unknown>;
  rowOf: (item: T) => ArchivedRowData;
  dateOf: (item: T) => string;
  keyOf: (item: T) => string;
}) {
  const t = useTranslations("common.archived");
  const [rows, setRows] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [restoring, setRestoring] = useState<string | null>(null);
  const [filter, setFilter] = useState("");
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await load(filter);
        if (!active) return;
        setRows(data);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("actionFailed"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter, nonce]);

  async function onRestore(item: T) {
    const id = keyOf(item);
    setRestoring(id);
    setError(null);
    try {
      await restore(item);
      setRows((prev) => prev.filter((r) => keyOf(r) !== id));
    } catch (e) {
      setError(e instanceof Error ? e.message : t("actionFailed"));
    } finally {
      setRestoring(null);
    }
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader icon={Archive} title={title} subtitle={subtitle}>
        <button
          type="button"
          onClick={() => setNonce((n) => n + 1)}
          disabled={loading}
          aria-label={t("refresh")}
          className="inline-flex size-10 items-center justify-center rounded-button border border-hairline text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} />
        </button>
        <Link
          href={backHref}
          className="inline-flex h-10 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
        >
          {backLabel}
        </Link>
      </PageHeader>

      {filters.length > 0 ? (
        <div className="mt-xl flex flex-wrap items-center gap-sm">
          {filters.map((tab) => (
            <button
              key={tab.key}
              type="button"
              onClick={() => setFilter(tab.key)}
              className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
                filter === tab.key
                  ? "bg-brand text-white"
                  : "border border-hairline text-ink hover:bg-surface-tint"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      ) : null}

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
            <p className="text-body-md text-muted">{emptyTitle}</p>
            <p className="max-w-content text-body-sm text-subtle">{emptyBody}</p>
          </div>
        ) : (
          rows.map((item, i) => {
            const date = new Date(dateOf(item));
            const newDay =
              i === 0 || !isSameDay(date, new Date(dateOf(rows[i - 1])));
            return (
              <Fragment key={keyOf(item)}>
                {newDay ? <DayDivider date={date} /> : null}
                <ArchivedRow
                  data={rowOf(item)}
                  busy={restoring === keyOf(item)}
                  onRestore={() => void onRestore(item)}
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
  data,
  busy,
  onRestore,
}: {
  data: ArchivedRowData;
  busy: boolean;
  onRestore: () => void;
}) {
  const t = useTranslations("common.archived");
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      <Link href={data.href} className="flex min-w-0 flex-1 items-center gap-md">
        {data.leading}
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-sm">
            <span className="truncate text-body-md text-ink">{data.number}</span>
            <span className="inline-flex items-center rounded-full bg-hero-panel px-sm py-px text-body-sm font-semibold text-muted">
              {data.status}
            </span>
          </div>
          <p className="truncate text-body-sm text-muted">{data.subtitle}</p>
        </div>
      </Link>
      {data.trailing ? (
        <span className="shrink-0 text-body-md text-ink">{data.trailing}</span>
      ) : null}
      <button
        type="button"
        onClick={onRestore}
        disabled={busy}
        className="inline-flex h-9 shrink-0 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
      >
        <ArchiveRestore size={16} />
        {busy ? t("restoring") : t("restore")}
      </button>
    </div>
  );
}
