"use client";

import { useEffect, useState } from "react";
import { LineChart } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { LineChart as TrendLineChart } from "@/shared/ui/charts";
import { CardsSkeleton, ListRowsSkeleton } from "@/shared/ui/skeleton";
import { formatINR } from "@/shared/money";
import {
  dateInputToIso,
  financialYearStartInput,
  inputDateDaysAgo,
  startOfMonthInput,
  todayInputDate,
} from "@/shared/datetime";
import {
  getGstReport,
  getPnlReport,
  getPurchasesReport,
  getSalesReport,
} from "@/features/reports/api";
import type { GstReport, PnlReport, PurchasesReport, SalesReport } from "@/features/reports/schema";

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

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      const range = { from: dateInputToIso(from), to: dateInputToIso(to, true) };
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
  }, [kind, from, to]);

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
          <PnlView r={report.data} />
        )}
      </div>
    </div>
  );
}

/* ---------- controls ---------- */

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

function PnlView({ r }: { r: PnlReport }) {
  return (
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
    </div>
  );
}
