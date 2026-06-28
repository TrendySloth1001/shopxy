"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { LineChart, Search, Package, Clock, ChevronRight, X } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { LineChart as TrendLineChart } from "@/shared/ui/charts";
import { CardsSkeleton, ListRowsSkeleton } from "@/shared/ui/skeleton";
import { formatINR } from "@/shared/money";
import {
  dateInputToIso,
  financialYearStartInput,
  formatDateTime,
  inputDateDaysAgo,
  startOfMonthInput,
  todayInputDate,
} from "@/shared/datetime";
import {
  getGstReport,
  getPnlReport,
  getPurchasesReport,
  getSalesReport,
  getSoldItems,
  getSoldProducts,
  type Range,
} from "@/features/reports/api";
import type {
  GstReport,
  PnlReport,
  PurchasesReport,
  SalesReport,
  SoldItem,
  SoldProduct,
} from "@/features/reports/schema";

type Kind = "sales" | "purchases" | "gst" | "pnl";
const TABS: { key: Kind; label: string }[] = [
  { key: "sales", label: "Sales" },
  { key: "purchases", label: "Purchases" },
  { key: "gst", label: "GST" },
  { key: "pnl", label: "P&L" },
];

type ReportData =
  | { kind: "sales"; data: SalesReport }
  | { kind: "purchases"; data: PurchasesReport }
  | { kind: "gst"; data: GstReport }
  | { kind: "pnl"; data: PnlReport };

export default function ReportsPage() {
  const [kind, setKind] = useState<Kind>("sales");
  const [from, setFrom] = useState(() => inputDateDaysAgo(30));
  const [to, setTo] = useState(() => todayInputDate());

  const [report, setReport] = useState<ReportData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // One ISO range, shared by the report fetch and the P&L sold-items table, so
  // they stay in lockstep and the table only refetches when the range changes.
  const range = useMemo<Range>(
    () => ({ from: dateInputToIso(from), to: dateInputToIso(to, true) }),
    [from, to],
  );

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        let next: ReportData;
        if (kind === "sales") next = { kind, data: await getSalesReport(range) };
        else if (kind === "purchases") next = { kind, data: await getPurchasesReport(range) };
        else if (kind === "gst") next = { kind, data: await getGstReport(range) };
        else next = { kind, data: await getPnlReport(range) };
        if (!active) return;
        setReport(next);
        setError(null);
      } catch (e) {
        if (active) {
          setError(e instanceof Error ? e.message : "Could not load the report.");
          setReport(null);
        }
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [kind, range]);

  function preset(p: "month" | "30d" | "fy") {
    setTo(todayInputDate());
    setFrom(p === "month" ? startOfMonthInput() : p === "fy" ? financialYearStartInput() : inputDateDaysAgo(30));
  }

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={LineChart}
        tone="teal"
        title="Reports"
        subtitle="Sales, purchases, GST and profit over a date range — from your confirmed invoices, returns and stock."
      />

      {/* Tabs */}
      <div className="mt-xl flex flex-wrap items-center gap-sm">
        {TABS.map((t) => (
          <button
            key={t.key}
            type="button"
            onClick={() => setKind(t.key)}
            className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
              kind === t.key ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Range */}
      <div className="mt-md flex flex-wrap items-end gap-md">
        <DateField label="From" value={from} max={to} onChange={setFrom} />
        <DateField label="To" value={to} min={from} max={todayInputDate()} onChange={setTo} />
        <div className="flex flex-wrap items-center gap-xs">
          <PresetChip label="This month" onClick={() => preset("month")} />
          <PresetChip label="Last 30 days" onClick={() => preset("30d")} />
          <PresetChip label="This FY" onClick={() => preset("fy")} />
        </div>
      </div>

      {error ? (
        <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {loading ? (
          <div className="space-y-xxl">
            <CardsSkeleton count={3} />
            <ListRowsSkeleton rows={6} leading={false} />
          </div>
        ) : !report ? null : report.kind === "sales" ? (
          <SalesView r={report.data} />
        ) : report.kind === "purchases" ? (
          <PurchasesView r={report.data} />
        ) : report.kind === "gst" ? (
          <GstView r={report.data} />
        ) : (
          <PnlView r={report.data} range={range} />
        )}
      </div>
    </div>
  );
}

/* ---------- controls ---------- */

const dateInput =
  "h-10 rounded-input border border-hairline bg-field px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

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

/* ---------- shared presentation ---------- */

function BigStat({ label, value, hint, tone }: { label: string; value: string; hint?: string; tone?: "ink" | "success" | "error" }) {
  const color = tone === "success" ? "text-success" : tone === "error" ? "text-error" : "text-ink";
  return (
    <div>
      <p className="text-label-md uppercase tracking-wide text-subtle">{label}</p>
      <p className={`mt-xs text-display-sm font-bold tabular-nums ${color}`}>{value}</p>
      {hint ? <p className="mt-xs text-body-sm text-muted">{hint}</p> : null}
    </div>
  );
}

function SectionHeading({ children }: { children: React.ReactNode }) {
  return <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">{children}</h2>;
}

function LeaderRow({ name, sub, value, amount, max }: { name: string; sub?: string; value: string; amount: number; max: number }) {
  const pct = max > 0 ? Math.max(2, Math.round((amount / max) * 100)) : 0;
  return (
    <div className="border-b border-hairline py-md">
      <div className="flex items-center justify-between gap-md">
        <div className="min-w-0 flex-1">
          <p className="truncate text-body-md text-ink">{name}</p>
          {sub ? <p className="truncate text-body-sm text-muted">{sub}</p> : null}
        </div>
        <span className="shrink-0 text-body-md font-semibold tabular-nums text-ink">{value}</span>
      </div>
      <div className="mt-sm h-1.5 w-full overflow-hidden rounded-full bg-hairline">
        <span className="block h-full rounded-full bg-brand" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

function labelDay(iso?: string): string {
  if (!iso) return "";
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "" : d.toLocaleDateString("en-IN", { day: "numeric", month: "short" });
}

/** Trailing simple moving average (smooths the daily noise). */
function movingAverage(values: number[], window = 7): number[] {
  return values.map((_, i) => {
    const slice = values.slice(Math.max(0, i - window + 1), i + 1);
    return slice.reduce((s, v) => s + v, 0) / slice.length;
  });
}

/**
 * Daily trend line with a 7-day moving-average overlay and a run-rate line.
 * The projection is a naive "at this pace" estimate, not a forecast — labelled
 * as such so it isn't read as a promise.
 */
function TrendChart({ points }: { points: { day: string; amount: number }[] }) {
  if (points.length === 0) return <EmptyHint>No activity in this range.</EmptyHint>;
  const values = points.map((p) => p.amount);
  const total = values.reduce((s, v) => s + v, 0);
  const perDay = points.length > 0 ? total / points.length : 0;
  return (
    <section>
      <TrendLineChart
        points={points.map((p) => ({ label: labelDay(p.day), value: p.amount }))}
        overlay={points.length >= 4 ? movingAverage(values) : undefined}
        heightClass="h-40 sm:h-52"
        ariaLabel="Daily trend"
        formatValue={formatINR}
      />
      <div className="mt-xs flex justify-between text-body-sm text-subtle">
        <span>{labelDay(points[0].day)}</span>
        <span>{labelDay(points[points.length - 1].day)}</span>
      </div>
      <p className="mt-sm text-body-sm text-muted">
        ≈ {formatINR(perDay)}/day at this pace · ~{formatINR(perDay * 30)} over 30 days
        {points.length >= 4 ? " · dashed line is the 7-day average" : ""}
      </p>
    </section>
  );
}

function TotalRow({ label, value, strong, big }: { label: string; value: string; strong?: boolean; big?: boolean }) {
  return (
    <div className={`flex items-center justify-between py-sm ${strong ? "border-t border-hairline" : ""}`}>
      <span className={`${big ? "text-title-md" : "text-body-md"} ${strong ? "text-ink" : "text-muted"}`}>{label}</span>
      <span className={`tabular-nums ${big ? "text-title-lg font-bold" : strong ? "text-body-md font-semibold" : "text-body-md"} text-ink`}>
        {value}
      </span>
    </div>
  );
}

function EmptyHint({ children }: { children: React.ReactNode }) {
  return <p className="py-lg text-center text-body-sm text-subtle">{children}</p>;
}

/**
 * One row of the P&L "proof" statement. `kind`:
 *   - line     — a contributing input (with a muted `basis` note explaining it)
 *   - subtotal — a hairline-topped running figure (Revenue, COGS, Gross profit)
 *   - total    — the final Net profit (heavier, hairline-topped)
 */
function StatementRow({
  label,
  basis,
  value,
  kind = "line",
}: {
  label: string;
  basis?: string;
  value: string;
  kind?: "line" | "subtotal" | "total";
}) {
  const subtotal = kind === "subtotal";
  const total = kind === "total";
  const ruled = subtotal || total ? "border-t border-hairline" : "";
  const labelCls = total
    ? "text-title-md text-ink"
    : subtotal
      ? "text-body-md font-semibold text-ink"
      : "text-body-md text-muted";
  const valueCls = total
    ? "text-title-lg font-bold text-ink"
    : subtotal
      ? "text-body-md font-semibold text-ink"
      : "text-body-md text-ink";
  return (
    <tr className={ruled}>
      <td className={`py-sm pr-lg align-top ${labelCls}`}>
        <span className="block">{label}</span>
        {basis ? (
          <span className="mt-px block text-body-sm font-normal text-subtle">{basis}</span>
        ) : null}
      </td>
      <td className={`py-sm text-right align-top tabular-nums ${valueCls}`}>{value}</td>
    </tr>
  );
}

/* ---------- views ---------- */

function SalesView({ r }: { r: SalesReport }) {
  const maxProd = Math.max(...r.topProducts.map((p) => p.revenue), 0);
  const maxCust = Math.max(...r.topCustomers.map((c) => c.revenue), 0);
  return (
    <div className="flex flex-col gap-xxl">
      <BigStat
        label="Total sales"
        value={formatINR(r.summary.total)}
        hint={`${r.summary.invoiceCount} confirmed invoices · ${formatINR(r.summary.taxAmount)} GST · net ${formatINR(r.summary.netRevenue)} after refunds`}
      />
      <TrendChart points={r.daily.map((d) => ({ day: d.day, amount: d.revenue }))} />
      <section>
        <SectionHeading>Top products</SectionHeading>
        {r.topProducts.length === 0 ? (
          <EmptyHint>No sales in this range.</EmptyHint>
        ) : (
          r.topProducts.map((p, i) => (
            <LeaderRow key={i} name={p.productName ?? "Product"} sub={`${p.quantity} sold${p.productSku ? ` · ${p.productSku}` : ""}`} value={formatINR(p.revenue)} amount={p.revenue} max={maxProd} />
          ))
        )}
      </section>
      <section>
        <SectionHeading>Top customers</SectionHeading>
        {r.topCustomers.length === 0 ? (
          <EmptyHint>No customers in this range.</EmptyHint>
        ) : (
          r.topCustomers.map((c, i) => (
            <LeaderRow key={i} name={c.name ?? "Customer"} sub={`${c.invoices} ${c.invoices === 1 ? "invoice" : "invoices"}`} value={formatINR(c.revenue)} amount={c.revenue} max={maxCust} />
          ))
        )}
      </section>
    </div>
  );
}

function PurchasesView({ r }: { r: PurchasesReport }) {
  const maxProd = Math.max(...r.topProducts.map((p) => p.spend), 0);
  const maxVend = Math.max(...r.topVendors.map((v) => v.spend), 0);
  return (
    <div className="flex flex-col gap-xxl">
      <BigStat
        label="Total purchases"
        value={formatINR(r.summary.total)}
        hint={`${r.summary.invoiceCount} confirmed bills · ${formatINR(r.summary.taxAmount)} GST`}
      />
      <TrendChart points={r.daily.map((d) => ({ day: d.day, amount: d.spend }))} />
      <section>
        <SectionHeading>Top purchased products</SectionHeading>
        {r.topProducts.length === 0 ? (
          <EmptyHint>No purchases in this range.</EmptyHint>
        ) : (
          r.topProducts.map((p, i) => (
            <LeaderRow key={i} name={p.productName ?? "Product"} sub={`${p.quantity} bought${p.productSku ? ` · ${p.productSku}` : ""}`} value={formatINR(p.spend)} amount={p.spend} max={maxProd} />
          ))
        )}
      </section>
      <section>
        <SectionHeading>Top vendors</SectionHeading>
        {r.topVendors.length === 0 ? (
          <EmptyHint>No vendors in this range.</EmptyHint>
        ) : (
          r.topVendors.map((v, i) => (
            <LeaderRow key={i} name={v.name ?? "Vendor"} sub={`${v.invoices} ${v.invoices === 1 ? "bill" : "bills"}`} value={formatINR(v.spend)} amount={v.spend} max={maxVend} />
          ))
        )}
      </section>
    </div>
  );
}

function GstView({ r }: { r: GstReport }) {
  const owes = r.netPayable >= 0;
  return (
    <div className="flex flex-col gap-xxl">
      <div className="grid grid-cols-1 gap-xl sm:grid-cols-2">
        <BigStat label="Output GST" value={formatINR(r.outputTax)} hint="Collected on sales" />
        <BigStat label="Input GST" value={formatINR(r.inputTax)} hint="Paid on purchases" />
      </div>
      <BigStat
        label="Net GST payable"
        value={formatINR(Math.abs(r.netPayable))}
        tone={owes ? "error" : "success"}
        hint={owes ? "You owe this to the tax authority" : "You have an input credit"}
      />
      <section>
        <SectionHeading>Output GST by rate</SectionHeading>
        {r.outputByRate.length === 0 ? <EmptyHint>No output GST in this range.</EmptyHint> : r.outputByRate.map((g, i) => <RateRow key={i} rate={g.rate} taxable={g.taxable} tax={g.tax} />)}
      </section>
      <section>
        <SectionHeading>Input GST by rate</SectionHeading>
        {r.inputByRate.length === 0 ? <EmptyHint>No input GST in this range.</EmptyHint> : r.inputByRate.map((g, i) => <RateRow key={i} rate={g.rate} taxable={g.taxable} tax={g.tax} />)}
      </section>
    </div>
  );
}

function RateRow({ rate, taxable, tax }: { rate: number; taxable: number; tax: number }) {
  return (
    <div className="flex items-center justify-between gap-md border-b border-hairline py-md">
      <span className="inline-flex h-7 min-w-12 items-center justify-center rounded-full bg-surface-tint px-sm text-body-sm font-semibold text-ink">
        {rate}%
      </span>
      <div className="flex flex-1 items-center justify-end gap-xl">
        <span className="text-body-sm text-muted">
          Taxable <span className="tabular-nums text-ink">{formatINR(taxable)}</span>
        </span>
        <span className="text-body-md font-semibold tabular-nums text-ink">{formatINR(tax)}</span>
      </div>
    </div>
  );
}

function PnlView({ r, range }: { r: PnlReport; range: Range }) {
  // The headline figures are already netted (revenue net of returns, COGS net
  // of restocked returns). Add the netted-out parts back to show the gross
  // inputs each line is built from — that's the "proof" the table makes visible.
  const refunds = r.refunds ?? 0;
  const returnedCogs = r.returnedCogs ?? 0;
  const grossSales = r.revenue + refunds;
  const grossCogs = r.cogs + returnedCogs;
  return (
    <div className="grid grid-cols-1 gap-xxxl lg:grid-cols-2 lg:gap-huge">
      {/* Left — the P&L statement and its proof. */}
      <div className="flex flex-col gap-xxl">
      <BigStat
        label="Net profit"
        value={formatINR(r.netProfit)}
        tone={r.netProfit >= 0 ? "success" : "error"}
        hint={`Gross margin ${(r.grossMargin * 100).toFixed(1)}%`}
      />
      <section className="max-w-form">
        <TotalRow label="Revenue" value={formatINR(r.revenue)} strong />
        <TotalRow label="Cost of goods sold" value={`− ${formatINR(r.cogs)}`} />
        <TotalRow label="Gross profit" value={formatINR(r.grossProfit)} strong />
        <TotalRow label="Adjustment write-offs" value={`− ${formatINR(r.writeoffs)}`} />
        <TotalRow label="Net profit" value={formatINR(r.netProfit)} strong big />
      </section>

      {/* Proof: every headline figure traced back to the documents it sums. */}
      <section className="max-w-content">
        <SectionHeading>How this is calculated</SectionHeading>
        <table className="w-full border-collapse">
          <caption className="sr-only">
            P&amp;L derivation from confirmed invoices, returns and stock adjustments
          </caption>
          <tbody>
            <StatementRow
              label="Confirmed sales"
              basis="Taxable value (ex-GST) of confirmed sale invoices, less credit notes"
              value={formatINR(grossSales)}
            />
            <StatementRow
              label="Less: sales returns"
              basis="Ex-GST value of refunded returns, pro-rated by returned quantity"
              value={`− ${formatINR(refunds)}`}
            />
            <StatementRow label="Revenue (A)" value={formatINR(r.revenue)} kind="subtotal" />

            <StatementRow
              label="Goods sold, at cost"
              basis="Stock cost layers consumed when each sale was confirmed"
              value={formatINR(grossCogs)}
            />
            <StatementRow
              label="Less: returned goods restocked"
              basis="Returned items put back into inventory at their consumed cost"
              value={`− ${formatINR(returnedCogs)}`}
            />
            <StatementRow
              label="Cost of goods sold (B)"
              value={formatINR(r.cogs)}
              kind="subtotal"
            />

            <StatementRow
              label="Gross profit (A − B)"
              value={formatINR(r.grossProfit)}
              kind="subtotal"
            />
            <StatementRow
              label="Less: stock write-offs"
              basis="Damage, expiry and shrinkage stock adjustments dated in this range"
              value={`− ${formatINR(r.writeoffs)}`}
            />
            <StatementRow
              label="Net profit (A − B − write-offs)"
              value={formatINR(r.netProfit)}
              kind="total"
            />
          </tbody>
        </table>
        <p className="mt-md text-body-sm text-subtle">
          Gross margin {(r.grossMargin * 100).toFixed(1)}% = gross profit ÷ revenue.
          Every figure is summed from confirmed invoices, refunded returns and
          stock adjustments dated in this range; estimates and proformas are
          excluded.
        </p>
      </section>
      </div>

      {/* Right — products sold in this range (one row per product); expand a
          row for its full sale timeline. */}
      <SoldProductsTable range={range} />
    </div>
  );
}

/**
 * Right-hand feed on the P&L view: an aggregated, spreadsheet-style table with
 * ONE row per product over the range (its number of sales, total qty, total
 * revenue). The list is bounded by the number of distinct products, not the raw
 * sale-line count, so it stays light even for a high-volume period. Expanding a
 * row lazily loads that product's full sale timeline a page at a time. Searches
 * server-side; horizontally scrollable on narrow screens.
 */
const SOLD_PAGE_SIZE = 25;
const TIMELINE_PAGE_SIZE = 15;
const SEARCH_DEBOUNCE_MS = 220;

function SoldProductsTable({ range }: { range: Range }) {
  const [query, setQuery] = useState("");
  const [search, setSearch] = useState(""); // debounced value actually queried
  const [products, setProducts] = useState<SoldProduct[]>([]);
  const [total, setTotal] = useState(0);
  const [totals, setTotals] = useState({ salesCount: 0, totalQuantity: 0, totalAmount: 0 });
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<number | null>(null);

  // Debounce the search box so a request isn't fired on every keystroke.
  useEffect(() => {
    const id = setTimeout(() => setSearch(query), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(id);
  }, [query]);

  // Reset and pull the first page whenever the range or the search changes.
  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      setError(null);
      setExpanded(null);
      try {
        const res = await getSoldProducts(range, 1, SOLD_PAGE_SIZE, search);
        if (!active) return;
        setProducts(res.data);
        setTotal(res.pagination.total);
        setTotals(res.totals);
        setPage(1);
      } catch (e) {
        if (!active) return;
        setError(e instanceof Error ? e.message : "Could not load sold products.");
        setProducts([]);
        setTotal(0);
        setTotals({ salesCount: 0, totalQuantity: 0, totalAmount: 0 });
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [range, search]);

  async function loadMore() {
    const next = page + 1;
    setLoadingMore(true);
    try {
      const res = await getSoldProducts(range, next, SOLD_PAGE_SIZE, search);
      setProducts((prev) => [...prev, ...res.data]);
      setTotal(res.pagination.total);
      setPage(next);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load more sold products.");
    } finally {
      setLoadingMore(false);
    }
  }

  const hasMore = products.length < total;
  const searching = query.trim().length > 0;

  return (
    <section>
      <div className="mb-md flex items-baseline justify-between gap-md">
        <SectionHeading>Products sold</SectionHeading>
        {!loading && total > 0 ? (
          <span className="shrink-0 text-body-sm tabular-nums text-subtle">
            {products.length} of {total}
          </span>
        ) : null}
      </div>

      {/* Search — filters server-side across the whole range, not just the
          loaded page. */}
      <div className="relative mb-md">
        <Search
          size={16}
          className="pointer-events-none absolute left-md top-1/2 -translate-y-1/2 text-subtle"
        />
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search by product or SKU…"
          aria-label="Search sold products"
          className="h-10 w-full rounded-input border border-hairline bg-field pl-xxxl pr-huge text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
        {query ? (
          <button
            type="button"
            onClick={() => setQuery("")}
            aria-label="Clear search"
            className="absolute right-sm top-1/2 inline-flex size-7 -translate-y-1/2 items-center justify-center rounded-full text-subtle transition-colors hover:bg-surface-tint hover:text-ink"
          >
            <X size={14} />
          </button>
        ) : null}
      </div>

      {loading ? (
        <ListRowsSkeleton rows={6} leading={false} />
      ) : error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : products.length === 0 ? (
        <EmptyHint>
          {searching
            ? `No sold products match “${query.trim()}”.`
            : "No products sold in this range."}
        </EmptyHint>
      ) : (
        <>
          <div className="overflow-x-auto rounded-md border border-hairline">
            <table
              style={{ minWidth: "var(--container-form)" }}
              className="w-full border-collapse text-left"
            >
              <thead>
                <tr className="bg-surface-tint">
                  <Th>Product</Th>
                  <Th align="right">Sales</Th>
                  <Th align="right">Qty</Th>
                  <Th align="right">Amount</Th>
                </tr>
              </thead>
              <tbody>
                {products.map((p) => (
                  <ProductRow
                    key={p.productId}
                    product={p}
                    range={range}
                    expanded={expanded === p.productId}
                    onToggle={() =>
                      setExpanded((cur) => (cur === p.productId ? null : p.productId))
                    }
                  />
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t border-hairline bg-surface-tint">
                  <td className="px-md py-sm text-label-md uppercase tracking-wide text-muted">
                    Total
                  </td>
                  <td className="whitespace-nowrap px-md py-sm text-right text-body-sm font-semibold tabular-nums text-ink">
                    {totals.salesCount} {totals.salesCount === 1 ? "sale" : "sales"}
                  </td>
                  <td className="whitespace-nowrap px-md py-sm text-right text-body-sm font-semibold tabular-nums text-ink">
                    {fmtQty(totals.totalQuantity)}
                  </td>
                  <td className="whitespace-nowrap px-md py-sm text-right text-body-md font-bold tabular-nums text-ink">
                    {formatINR(totals.totalAmount)}
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
          {hasMore ? (
            <button
              type="button"
              onClick={loadMore}
              disabled={loadingMore}
              className="mt-md inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
            >
              {loadingMore ? "Loading…" : `Load more (${total - products.length} left)`}
            </button>
          ) : (
            <p className="mt-md text-body-sm text-subtle">
              All {total} {total === 1 ? "product" : "products"} shown.
            </p>
          )}
        </>
      )}
    </section>
  );
}

/** One aggregated product row + its lazily-loaded sale timeline when expanded. */
function ProductRow({
  product,
  range,
  expanded,
  onToggle,
}: {
  product: SoldProduct;
  range: Range;
  expanded: boolean;
  onToggle: () => void;
}) {
  const tone = toneFor(product.productSku || product.productName || String(product.productId));
  const unit = product.unit ?? "";
  return (
    <>
      <tr
        onClick={onToggle}
        aria-expanded={expanded}
        className={`cursor-pointer border-b border-hairline transition-colors last:border-b-0 hover:bg-surface-tint ${
          expanded ? "bg-surface-tint" : ""
        }`}
      >
        <td className="max-w-0 px-md py-sm align-middle">
          <div className="flex min-w-0 items-center gap-sm">
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                onToggle();
              }}
              aria-expanded={expanded}
              aria-label={expanded ? "Hide sale timeline" : "Show sale timeline"}
              className="inline-flex size-6 shrink-0 items-center justify-center rounded-md text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <ChevronRight
                size={16}
                className={`transition-transform ${expanded ? "rotate-90" : ""}`}
              />
            </button>
            <span className={`flex size-8 shrink-0 items-center justify-center rounded-md ${tone}`}>
              <Package size={16} />
            </span>
            <div className="min-w-0">
              <span className="block truncate text-body-md text-ink">
                {product.productName ?? "Product"}
              </span>
              {product.productSku ? (
                <span className="block truncate text-body-sm text-subtle">{product.productSku}</span>
              ) : null}
            </div>
          </div>
        </td>
        <td className="whitespace-nowrap px-md py-sm text-right align-middle">
          <span
            className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold tabular-nums ${countTone(product.salesCount)}`}
          >
            {product.salesCount} {product.salesCount === 1 ? "sale" : "sales"}
          </span>
        </td>
        <td className="whitespace-nowrap px-md py-sm text-right align-middle">
          <span
            className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold tabular-nums ${qtyTone(product.totalQuantity)}`}
          >
            {fmtQty(product.totalQuantity)}
            {unit ? ` ${unit}` : ""}
          </span>
        </td>
        <td className="whitespace-nowrap px-md py-sm text-right align-middle text-body-md font-semibold tabular-nums text-ink">
          {formatINR(product.totalAmount)}
        </td>
      </tr>
      {expanded ? (
        <tr>
          <td colSpan={4} className="border-b border-hairline bg-surface p-0">
            <ProductTimeline range={range} product={product} />
          </td>
        </tr>
      ) : null}
    </>
  );
}

/** The drill-down: a single product's individual sales, newest first, loaded a
 *  page at a time only once the row is expanded. Rendered as a light timeline
 *  (not a nested grid) with a sticky product total at the bottom. */
function ProductTimeline({ range, product }: { range: Range; product: SoldProduct }) {
  const productId = product.productId;
  const unit = product.unit ?? "";
  const [items, setItems] = useState<SoldItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await getSoldItems(range, productId, 1, TIMELINE_PAGE_SIZE);
        if (!active) return;
        setItems(res.data);
        setTotal(res.pagination.total);
        setPage(1);
      } catch (e) {
        if (!active) return;
        setError(e instanceof Error ? e.message : "Could not load the sale timeline.");
        setItems([]);
        setTotal(0);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [range, productId]);

  async function loadMore() {
    const next = page + 1;
    setLoadingMore(true);
    try {
      const res = await getSoldItems(range, productId, next, TIMELINE_PAGE_SIZE);
      setItems((prev) => [...prev, ...res.data]);
      setTotal(res.pagination.total);
      setPage(next);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load more sales.");
    } finally {
      setLoadingMore(false);
    }
  }

  const hasMore = items.length < total;

  return (
    <div className="px-lg py-md">
      {loading ? (
        <ListRowsSkeleton rows={3} leading={false} />
      ) : error ? (
        <p className="py-sm text-body-sm text-error">{error}</p>
      ) : items.length === 0 ? (
        <p className="py-sm text-body-sm text-subtle">No sales found for this product.</p>
      ) : (
        <ol className="flex flex-col gap-xs">
          {items.map((ev, i) => {
            const row = (
              <div className="flex items-center gap-sm rounded-md px-sm py-xs transition-colors hover:bg-surface-tint">
                <Clock size={14} className={`shrink-0 ${recencyColor(ev.soldAt)}`} />
                <span className="shrink-0 text-body-sm text-ink">{formatDateTime(ev.soldAt)}</span>
                <span className="min-w-0 flex-1 truncate text-body-sm text-subtle">
                  {ev.invoiceNo ?? ""}
                </span>
                <span
                  className={`inline-flex shrink-0 items-center rounded-full px-sm py-px text-body-sm font-semibold tabular-nums ${qtyTone(ev.quantity)}`}
                >
                  {fmtQty(ev.quantity)}
                  {unit ? ` ${unit}` : ""}
                </span>
                <span className="w-20 shrink-0 text-right text-body-sm font-semibold tabular-nums text-ink">
                  {formatINR(ev.total)}
                </span>
              </div>
            );
            return (
              <li key={i}>
                {ev.invoiceId ? (
                  <Link href={`/dashboard/invoices/${ev.invoiceId}`} className="block">
                    {row}
                  </Link>
                ) : (
                  row
                )}
              </li>
            );
          })}
        </ol>
      )}

      {!loading && hasMore ? (
        <button
          type="button"
          onClick={loadMore}
          disabled={loadingMore}
          className="mt-sm inline-flex h-8 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
        >
          {loadingMore ? "Loading…" : `Load more (${total - items.length} left)`}
        </button>
      ) : null}

      {!loading && !error ? (
        <div className="mt-sm flex items-center justify-between gap-md border-t border-hairline pt-sm">
          <span className="text-label-md uppercase tracking-wide text-subtle">
            Total · {product.salesCount} {product.salesCount === 1 ? "sale" : "sales"} ·{" "}
            {fmtQty(product.totalQuantity)}
            {unit ? ` ${unit}` : ""}
          </span>
          <span className="text-body-md font-bold tabular-nums text-ink">
            {formatINR(product.totalAmount)}
          </span>
        </div>
      ) : null}
    </div>
  );
}

function Th({ children, align }: { children: React.ReactNode; align?: "right" }) {
  return (
    <th
      className={`whitespace-nowrap border-b border-hairline px-md py-sm text-label-md uppercase tracking-wide text-muted ${
        align === "right" ? "text-right" : "text-left"
      }`}
    >
      {children}
    </th>
  );
}

/** Per-product icon tint — same product always gets the same colour, so a
 *  repeated item is easy to spot while scanning the feed. */
const SOLD_TONES = [
  "bg-accent-teal-soft text-accent-teal",
  "bg-accent-indigo-soft text-accent-indigo",
  "bg-accent-amber-soft text-accent-amber",
  "bg-accent-rose-soft text-accent-rose",
  "bg-brand-soft text-brand-strong",
] as const;

function toneFor(key: string): string {
  let h = 0;
  for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) >>> 0;
  return SOLD_TONES[h % SOLD_TONES.length];
}

/** Qty chip colour by volume: bigger sale → warmer/stronger fill. */
function qtyTone(q: number): string {
  if (q >= 5) return "bg-brand-soft text-brand-strong";
  if (q >= 2) return "bg-info-soft text-info";
  return "bg-surface-tint text-muted";
}

/** Sales-count chip colour: more repeat sales → stronger fill. */
function countTone(c: number): string {
  if (c >= 10) return "bg-brand-soft text-brand-strong";
  if (c >= 3) return "bg-info-soft text-info";
  return "bg-surface-tint text-muted";
}

/** Whole number when integral, else 2dp. */
function fmtQty(q: number): string {
  return Number.isInteger(q) ? String(q) : q.toFixed(2);
}

/** Clock colour by recency: today → green, this week → blue, older → muted. */
function recencyColor(iso: string): string {
  const days = (Date.now() - new Date(iso).getTime()) / 86_400_000;
  if (days < 1) return "text-success";
  if (days < 7) return "text-info";
  return "text-subtle";
}

