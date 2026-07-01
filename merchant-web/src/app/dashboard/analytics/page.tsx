"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { ArrowDown, ArrowUp, Search } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { CardsSkeleton, ListRowsSkeleton } from "@/shared/ui/skeleton";
import { getProductAnalytics } from "@/features/analytics/api";
import { useAnalyticsRange } from "@/features/analytics/range-context";
import { KpiStrip, SectionHeading, aInt, aPct } from "@/features/analytics/ui";
import type { AnalyticsRow, AnalyticsSortKey, ProductAnalytics } from "@/features/analytics/schema";

const PAGE = 100;

export default function AnalyticsTablePage() {
  const { iso } = useAnalyticsRange();
  const t = useTranslations("analytics");

  const [data, setData] = useState<ProductAnalytics | null>(null);
  const [extra, setExtra] = useState<AnalyticsRow[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [sortKey, setSortKey] = useState<AnalyticsSortKey>("purchases");
  const [sortAsc, setSortAsc] = useState(false);
  const [search, setSearch] = useState("");

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const a = await getProductAnalytics(iso, { limit: PAGE });
        if (!active) return;
        setData(a);
        setExtra([]);
        setCursor(a.nextCursor ?? null);
        setError(null);
      } catch (e) {
        if (active) {
          setError(e instanceof Error ? e.message : t("errors.load"));
          setData(null);
        }
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [iso, t]);

  const loadMore = useCallback(async () => {
    if (!cursor || loadingMore) return;
    setLoadingMore(true);
    try {
      const a = await getProductAnalytics(iso, { limit: PAGE, cursor });
      setExtra((prev) => [...prev, ...a.products]);
      setCursor(a.nextCursor ?? null);
    } catch {
      /* keep current rows */
    } finally {
      setLoadingMore(false);
    }
  }, [cursor, loadingMore, iso]);

  function toggleSort(key: AnalyticsSortKey) {
    if (key === sortKey) setSortAsc((a) => !a);
    else {
      setSortKey(key);
      setSortAsc(key === "productName");
    }
  }

  const all = useMemo(() => [...(data?.products ?? []), ...extra], [data, extra]);
  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    const base = q ? all.filter((p) => (p.productName ?? "").toLowerCase().includes(q)) : all;
    const sorted = [...base].sort((a, b) => {
      if (sortKey === "productName") return (a.productName ?? "").localeCompare(b.productName ?? "");
      return (a[sortKey] as number) - (b[sortKey] as number);
    });
    return sortAsc ? sorted : sorted.reverse();
  }, [all, search, sortKey, sortAsc]);

  if (loading) {
    return (
      <div className="mt-xl space-y-xxl">
        <CardsSkeleton count={8} />
        <ListRowsSkeleton rows={8} leading={false} />
      </div>
    );
  }
  if (error || !data) {
    return <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error ?? t("errors.noData")}</p>;
  }

  return (
    <>
      <div className="mt-xl">
        <KpiStrip totals={data.totals} />
      </div>

      <Divider className="my-xxl" />
      <div className="flex flex-wrap items-center justify-between gap-sm">
        <SectionHeading>{t("table.byProduct")}</SectionHeading>
        <div className="flex w-full items-center gap-sm rounded-input border border-hairline bg-field px-md focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft sm:w-64">
          <Search size={15} className="shrink-0 text-subtle" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("table.filterPlaceholder")}
            className="h-9 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
          />
        </div>
      </div>

      {rows.length === 0 ? (
        <p className="py-xl text-center text-body-sm text-subtle">
          {search ? t("table.noMatch") : t("table.noActivity")}
        </p>
      ) : (
        <div className="mt-sm overflow-x-auto">
          <table className="w-full min-w-[44rem] border-collapse">
            <thead>
              <tr className="border-b border-hairline text-left">
                <Th label={t("columns.product")} col="productName" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} align="left" />
                <Th label={t("columns.imp")} col="impressions" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                <Th label={t("columns.taps")} col="taps" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                <Th label={t("columns.views")} col="views" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                <Th label={t("columns.atc")} col="addToCart" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                <Th label={t("columns.buys")} col="purchases" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                <Th label={t("columns.ctr")} col="ctr" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                <Th label={t("columns.cvr")} col="cvr" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <Row key={r.productId} row={r} productFallback={t("common.product")} />
              ))}
            </tbody>
          </table>
        </div>
      )}

      {cursor && !search ? (
        <div className="mt-lg flex justify-center">
          <button
            type="button"
            onClick={loadMore}
            disabled={loadingMore}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
          >
            {loadingMore ? t("common.loading") : t("table.loadMore")}
          </button>
        </div>
      ) : null}
    </>
  );
}

function Th({
  label,
  col,
  sortKey,
  sortAsc,
  onSort,
  align = "right",
}: {
  label: string;
  col: AnalyticsSortKey;
  sortKey: AnalyticsSortKey;
  sortAsc: boolean;
  onSort: (k: AnalyticsSortKey) => void;
  align?: "left" | "right";
}) {
  const active = sortKey === col;
  return (
    <th className={`py-sm ${align === "right" ? "text-right" : "text-left"}`}>
      <button
        type="button"
        onClick={() => onSort(col)}
        className={`inline-flex items-center gap-xs text-label-md uppercase tracking-wide transition-colors hover:text-ink ${
          active ? "text-ink" : "text-subtle"
        } ${align === "right" ? "flex-row-reverse" : ""}`}
      >
        {label}
        {active ? sortAsc ? <ArrowUp size={12} /> : <ArrowDown size={12} /> : null}
      </button>
    </th>
  );
}

function Row({ row, productFallback }: { row: AnalyticsRow; productFallback: string }) {
  return (
    <tr className="border-b border-hairline transition-colors hover:bg-surface-tint">
      <td className="max-w-xs truncate py-sm pr-md text-body-md text-ink">{row.productName ?? productFallback}</td>
      <Td value={aInt(row.impressions)} />
      <Td value={aInt(row.taps)} />
      <Td value={aInt(row.views)} />
      <Td value={aInt(row.addToCart)} />
      <Td value={aInt(row.purchases)} />
      <Td value={aPct(row.ctr)} />
      <Td value={aPct(row.cvr)} />
    </tr>
  );
}

function Td({ value }: { value: string }) {
  return <td className="py-sm pl-md text-right text-body-md tabular-nums text-muted">{value}</td>;
}
