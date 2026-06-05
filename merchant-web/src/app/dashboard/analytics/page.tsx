"use client";

import { useEffect, useMemo, useState } from "react";
import { ArrowDown, ArrowUp, BarChart3 } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { CardsSkeleton, ListRowsSkeleton } from "@/shared/ui/skeleton";
import { dateInputToIso, inputDateDaysAgo, startOfMonthInput, todayInputDate } from "@/shared/datetime";
import { getProductAnalytics } from "@/features/analytics/api";
import type { AnalyticsRow, AnalyticsSortKey, ProductAnalytics } from "@/features/analytics/schema";

const intFmt = new Intl.NumberFormat("en-IN");
const int = (v: number) => intFmt.format(Math.round(v));
const pct = (v: number) => `${(v * 100).toFixed(1)}%`;

export default function AnalyticsPage() {
  const [from, setFrom] = useState(() => inputDateDaysAgo(7));
  const [to, setTo] = useState(() => todayInputDate());
  const [data, setData] = useState<ProductAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [sortKey, setSortKey] = useState<AnalyticsSortKey>("purchases");
  const [sortAsc, setSortAsc] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const result = await getProductAnalytics({ from: dateInputToIso(from), to: dateInputToIso(to, true) });
        if (!active) return;
        setData(result);
        setError(null);
      } catch (e) {
        if (active) {
          setError(e instanceof Error ? e.message : "Could not load analytics.");
          setData(null);
        }
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [from, to]);

  function toggleSort(key: AnalyticsSortKey) {
    if (key === sortKey) setSortAsc((a) => !a);
    else {
      setSortKey(key);
      setSortAsc(key === "productName");
    }
  }

  const rows = useMemo(() => {
    const list = data?.products ?? [];
    const sorted = [...list].sort((a, b) => {
      if (sortKey === "productName") {
        return (a.productName ?? "").localeCompare(b.productName ?? "");
      }
      return (a[sortKey] as number) - (b[sortKey] as number);
    });
    return sortAsc ? sorted : sorted.reverse();
  }, [data, sortKey, sortAsc]);

  function preset(p: "7d" | "30d" | "month") {
    setTo(todayInputDate());
    setFrom(p === "month" ? startOfMonthInput() : p === "30d" ? inputDateDaysAgo(30) : inputDateDaysAgo(7));
  }

  const t = data?.totals;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={BarChart3}
        tone="indigo"
        title="Analytics"
        subtitle="How customers engage with your products — impressions through to purchases, with click-through and conversion rates."
      />

      {/* Range */}
      <div className="mt-xl flex flex-wrap items-end gap-md">
        <DateField label="From" value={from} max={to} onChange={setFrom} />
        <DateField label="To" value={to} min={from} max={todayInputDate()} onChange={setTo} />
        <div className="flex flex-wrap items-center gap-xs">
          <PresetChip label="Last 7 days" onClick={() => preset("7d")} />
          <PresetChip label="Last 30 days" onClick={() => preset("30d")} />
          <PresetChip label="This month" onClick={() => preset("month")} />
        </div>
      </div>

      {error ? (
        <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {loading ? (
        <div className="mt-xl space-y-xxl">
          <CardsSkeleton count={8} />
          <ListRowsSkeleton rows={6} leading={false} />
        </div>
      ) : t ? (
        <>
          {/* KPI strip */}
          <div className="mt-xl grid grid-cols-2 gap-x-lg gap-y-xl sm:grid-cols-4">
            <Kpi label="Impressions" value={int(t.impressions)} />
            <Kpi label="Taps" value={int(t.taps)} />
            <Kpi label="Views" value={int(t.views)} />
            <Kpi label="Add to cart" value={int(t.addToCart)} />
            <Kpi label="Purchases" value={int(t.purchases)} />
            <Kpi label="Wishlist" value={int(t.wishlistAdd)} />
            <Kpi label="CTR" value={pct(t.ctr)} hint="Taps ÷ impressions" />
            <Kpi label="CVR" value={pct(t.cvr)} hint="Purchases ÷ views" />
          </div>

          {/* Per-product table */}
          <h2 className="mb-sm mt-xxl text-label-md uppercase tracking-wide text-subtle">By product</h2>
          {rows.length === 0 ? (
            <p className="py-xl text-center text-body-sm text-subtle">No product activity in this range.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[44rem] border-collapse">
                <thead>
                  <tr className="border-b border-hairline text-left">
                    <Th label="Product" col="productName" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} align="left" />
                    <Th label="Imp" col="impressions" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="Taps" col="taps" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="Views" col="views" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="ATC" col="addToCart" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="Buys" col="purchases" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="CTR" col="ctr" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="CVR" col="cvr" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((r) => (
                    <Row key={r.productId} row={r} />
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      ) : null}
    </div>
  );
}

function Kpi({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div>
      <p className="text-label-md uppercase tracking-wide text-subtle">{label}</p>
      <p className="mt-xs text-headline-md font-bold tabular-nums text-ink">{value}</p>
      {hint ? <p className="text-body-sm text-subtle">{hint}</p> : null}
    </div>
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

function Row({ row }: { row: AnalyticsRow }) {
  return (
    <tr className="border-b border-hairline">
      <td className="max-w-xs truncate py-sm pr-md text-body-md text-ink">{row.productName ?? "Product"}</td>
      <Td value={int(row.impressions)} />
      <Td value={int(row.taps)} />
      <Td value={int(row.views)} />
      <Td value={int(row.addToCart)} />
      <Td value={int(row.purchases)} />
      <Td value={pct(row.ctr)} />
      <Td value={pct(row.cvr)} />
    </tr>
  );
}

function Td({ value }: { value: string }) {
  return <td className="py-sm pl-md text-right text-body-md tabular-nums text-muted">{value}</td>;
}

/* Range controls (mirrors the Reports page). */
const dateInput =
  "h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

function DateField({
  label,
  value,
  min,
  max,
  onChange,
}: {
  label: string;
  value: string;
  min?: string;
  max?: string;
  onChange: (v: string) => void;
}) {
  return (
    <label className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      <input type="date" value={value} min={min} max={max} onChange={(e) => onChange(e.target.value)} className={dateInput} />
    </label>
  );
}

function PresetChip({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
    >
      {label}
    </button>
  );
}
