"use client";

import { Fragment, useEffect, useState, type ReactNode } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { Archive, ArchiveRestore, RefreshCw } from "@/shared/icons";
import { PageHeader } from "@/shared/ui/page-header";
import { DayDivider } from "@/shared/ui/day-divider";
import { ListRowsSkeleton } from "@/shared/ui/skeleton";
import { isSameDay } from "@/shared/datetime";

/**
 * One page shape for every "Archived …" view — invoices, challans,
 * quotations.
 *
 * Archiving means the same thing for all three: the document leaves the
 * working list and KEEPS its number, because each number is a per-shop serial
 * allocated at create time and a run with a hole in it is a problem with an
 * auditor. None of them can be deleted, so this page is the only way back.
 *
 * Single-sourced rather than copied per feature so the three can't drift, and
 * deliberately the same shape as the Flutter merchant app's
 * `ArchivedDocumentsPage` — a merchant should read the same screen in either.
 */

/** A tab above the list. `key` is passed straight to `load` ("" = All). */
export type ArchivedFilter = { key: string; label: string };

/** The parts of a row that differ per document kind. */
export type ArchivedRowData = {
  href: string;
  /** The serial that stays allocated. The reason archiving exists. */
  number: string;
  status: string;
  /** Counterparty, usually. */
  subtitle: string;
  /** Right-hand figure — a total, an item count. Omitted when there isn't one. */
  trailing?: string;
  /** Optional leading disc (the sale/purchase arrow on invoices). */
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
  /** Fetches the archived page for the selected filter ("" = All). */
  load: (filter: string) => Promise<T[]>;
  restore: (item: T) => Promise<unknown>;
  rowOf: (item: T) => ArchivedRowData;
  /**
   * The date rows are grouped by. Must be the field the server sorts on,
   * otherwise a day heading repeats further down the scroll.
   */
  dateOf: (item: T) => string;
  keyOf: (item: T) => string;
}) {
  // Neutral strings — this page serves invoices, challans and quotations
  // alike, so it must not borrow any one feature's catalog.
  const t = useTranslations("common.archived");
  const [rows, setRows] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [restoring, setRestoring] = useState<string | null>(null);
  const [filter, setFilter] = useState("");
  const [nonce, setNonce] = useState(0);

  // The fetch runs inside an async IIFE so no setState happens synchronously
  // in the effect body, and `active` guards a response landing after unmount.
  //
  // The filter goes to the server rather than being applied over the loaded
  // page, so it still means something past the fetch limit.
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
    // `load` is redefined every render by the calling page; depending on it
    // would refetch in a loop. Filter + nonce are the real inputs.
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
            {/* The number is the point: it stays allocated, which is what
                makes archiving workable where deleting wasn't. */}
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
