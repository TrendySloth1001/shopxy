"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { LineChart, Search, Package, Clock, ChevronRight, X } from "@/shared/icons";
import { PageHeader } from "@/shared/ui/page-header";
import { LineChart as TrendLineChart } from "@/shared/ui/charts";
import { CardsSkeleton, ListRowsSkeleton } from "@/shared/ui/skeleton";
import { DatePicker } from "@/shared/ui/date-picker";
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
import { CalculatorSuite } from "@/features/reports/calculators";

type Kind = "sales" | "purchases" | "gst" | "pnl" | "calculator";
const TABS: Kind[] = ["sales", "purchases", "gst", "pnl", "calculator"];

type ReportData =
  | { kind: "sales"; data: SalesReport }
  | { kind: "purchases"; data: PurchasesReport }
  | { kind: "gst"; data: GstReport }
  | { kind: "pnl"; data: PnlReport };

export default function ReportsPage() {
  return (
    <Suspense>
      <ReportsContent />
    </Suspense>
  );
}

function ReportsContent() {
  const t = useTranslations("reports");
  const searchParams = useSearchParams();
  const [kind, setKind] = useState<Kind>(() => {
    const tab = searchParams.get("tab");
    return TABS.some((x) => x === tab) ? (tab as Kind) : "sales";
  });
  const quotationId = (() => {
    const raw = searchParams.get("quotation")?.trim();
    return raw ? raw : undefined;
  })();
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
      // The calculator tab is a live tool, not a date-range report — skip the
      // fetch entirely.
      if (kind === "calculator") {
        setReport(null);
        setError(null);
        setLoading(false);
        return;
      }
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
          setError(e instanceof Error ? e.message : t("errors.report"));
          setReport(null);
        }
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
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
        title={t("title")}
        subtitle={t("subtitle")}
      />

      {/* Tabs */}
      <div className="mt-xl flex flex-wrap items-center gap-sm">
        {TABS.map((tab) => (
          <button
            key={tab}
            type="button"
            onClick={() => setKind(tab)}
            className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
              kind === tab ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
            }`}
          >
            {t(`tabs.${tab}`)}
          </button>
        ))}
      </div>

      {/* Range — not relevant to the calculator tool */}
      {kind !== "calculator" ? (
        <div className="mt-md flex flex-wrap items-end gap-md">
          <DateField label={t("range.from")} value={from} max={to} onChange={setFrom} />
          <DateField label={t("range.to")} value={to} min={from} max={todayInputDate()} onChange={setTo} />
          <div className="flex flex-wrap items-center gap-xs">
            <PresetChip label={t("range.thisMonth")} onClick={() => preset("month")} />
            <PresetChip label={t("range.last30Days")} onClick={() => preset("30d")} />
            <PresetChip label={t("range.thisFy")} onClick={() => preset("fy")} />
          </div>
        </div>
      ) : null}

      {error ? (
        <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      <div className="mt-xl">
        {kind === "calculator" ? (
          <CalculatorSuite quotationId={quotationId} />
        ) : loading ? (
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
  return <DatePicker label={label} value={value} min={min} max={max} onChange={onChange} />;
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
  const t = useTranslations("reports");
  if (points.length === 0) return <EmptyHint>{t("trend.noActivity")}</EmptyHint>;
  const values = points.map((p) => p.amount);
  const total = values.reduce((s, v) => s + v, 0);
  const perDay = points.length > 0 ? total / points.length : 0;
  return (
    <section>
      <TrendLineChart
        points={points.map((p) => ({ label: labelDay(p.day), value: p.amount }))}
        overlay={points.length >= 4 ? movingAverage(values) : undefined}
        heightClass="h-40 sm:h-52"
        ariaLabel={t("trend.ariaLabel")}
        formatValue={formatINR}
      />
      <div className="mt-xs flex justify-between text-body-sm text-subtle">
        <span>{labelDay(points[0].day)}</span>
        <span>{labelDay(points[points.length - 1].day)}</span>
      </div>
      <p className="mt-sm text-body-sm text-muted">
        {t("trend.pace", { perDay: formatINR(perDay), perMonth: formatINR(perDay * 30) })}
        {points.length >= 4 ? t("trend.averageSuffix") : ""}
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
  const t = useTranslations("reports");
  const maxProd = Math.max(...r.topProducts.map((p) => p.revenue), 0);
  const maxCust = Math.max(...r.topCustomers.map((c) => c.revenue), 0);
  return (
    <div className="flex flex-col gap-xxl">
      <BigStat
        label={t("sales.total")}
        value={formatINR(r.summary.total)}
        hint={t("sales.summaryHint", {
          count: r.summary.invoiceCount,
          gst: formatINR(r.summary.taxAmount),
          net: formatINR(r.summary.netRevenue),
        })}
      />
      <TrendChart points={r.daily.map((d) => ({ day: d.day, amount: d.revenue }))} />
      <section>
        <SectionHeading>{t("sales.topProducts")}</SectionHeading>
        {r.topProducts.length === 0 ? (
          <EmptyHint>{t("sales.noSales")}</EmptyHint>
        ) : (
          r.topProducts.map((p, i) => (
            <LeaderRow key={i} name={p.productName ?? t("common.product")} sub={p.productSku ? t("sales.soldSubSku", { qty: p.quantity, sku: p.productSku }) : t("sales.soldSub", { qty: p.quantity })} value={formatINR(p.revenue)} amount={p.revenue} max={maxProd} />
          ))
        )}
      </section>
      <section>
        <SectionHeading>{t("sales.topCustomers")}</SectionHeading>
        {r.topCustomers.length === 0 ? (
          <EmptyHint>{t("sales.noCustomers")}</EmptyHint>
        ) : (
          r.topCustomers.map((c, i) => (
            <LeaderRow key={i} name={c.name ?? t("common.customer")} sub={t("sales.customerInvoices", { count: c.invoices })} value={formatINR(c.revenue)} amount={c.revenue} max={maxCust} />
          ))
        )}
      </section>
    </div>
  );
}

function PurchasesView({ r }: { r: PurchasesReport }) {
  const t = useTranslations("reports");
  const maxProd = Math.max(...r.topProducts.map((p) => p.spend), 0);
  const maxVend = Math.max(...r.topVendors.map((v) => v.spend), 0);
  return (
    <div className="flex flex-col gap-xxl">
      <BigStat
        label={t("purchases.total")}
        value={formatINR(r.summary.total)}
        hint={t("purchases.summaryHint", { count: r.summary.invoiceCount, gst: formatINR(r.summary.taxAmount) })}
      />
      <TrendChart points={r.daily.map((d) => ({ day: d.day, amount: d.spend }))} />
      <section>
        <SectionHeading>{t("purchases.topProducts")}</SectionHeading>
        {r.topProducts.length === 0 ? (
          <EmptyHint>{t("purchases.noPurchases")}</EmptyHint>
        ) : (
          r.topProducts.map((p, i) => (
            <LeaderRow key={i} name={p.productName ?? t("common.product")} sub={p.productSku ? t("purchases.boughtSubSku", { qty: p.quantity, sku: p.productSku }) : t("purchases.boughtSub", { qty: p.quantity })} value={formatINR(p.spend)} amount={p.spend} max={maxProd} />
          ))
        )}
      </section>
      <section>
        <SectionHeading>{t("purchases.topVendors")}</SectionHeading>
        {r.topVendors.length === 0 ? (
          <EmptyHint>{t("purchases.noVendors")}</EmptyHint>
        ) : (
          r.topVendors.map((v, i) => (
            <LeaderRow key={i} name={v.name ?? t("common.vendor")} sub={t("purchases.vendorBills", { count: v.invoices })} value={formatINR(v.spend)} amount={v.spend} max={maxVend} />
          ))
        )}
      </section>
    </div>
  );
}

function GstView({ r }: { r: GstReport }) {
  const t = useTranslations("reports");
  const owes = r.netPayable >= 0;
  const head = r.byHead;
  const outputCess = r.outputCess ?? 0;
  const inputCess = r.inputCess ?? 0;
  const hasCess = outputCess !== 0 || inputCess !== 0;
  const returnedGst = r.returns?.gst ?? 0;
  const hasGst = r.outputTax !== 0 || r.inputTax !== 0;
  return (
    <div className="flex flex-col gap-xxl">
      {/* Headline — three stats fill the width */}
      <div className="grid grid-cols-1 gap-xl sm:grid-cols-3">
        <BigStat label={t("gst.outputGst")} value={formatINR(r.outputTax)} hint={t("gst.collectedOnSales")} />
        <BigStat label={t("gst.inputGst")} value={formatINR(r.inputTax)} hint={t("gst.paidOnPurchases")} />
        <BigStat
          label={t("gst.netPayable")}
          value={formatINR(Math.abs(r.netPayable))}
          tone={owes ? "error" : "success"}
          hint={owes ? t("gst.owesHint") : t("gst.creditHint")}
        />
      </div>

      {/* Head-wise split — the GSTR-3B view: each head set off against its own
          input credit. */}
      {head && hasGst ? (
        <section className="max-w-content">
          <SectionHeading>{t("gst.netByHead")}</SectionHeading>
          <div className="overflow-hidden rounded-md border border-hairline">
            <div className="hidden bg-surface-tint px-md py-sm sm:flex sm:items-center sm:gap-md">
              <span className="flex-1 text-label-md uppercase tracking-wide text-muted">{t("gst.headCol")}</span>
              <span className="w-24 text-right text-label-md uppercase tracking-wide text-muted">
                {t("gst.outputCol")}
              </span>
              <span className="w-24 text-right text-label-md uppercase tracking-wide text-muted">
                {t("gst.inputCol")}
              </span>
              <span className="w-24 text-right text-label-md uppercase tracking-wide text-muted">
                {t("gst.netCol")}
              </span>
            </div>
            <HeadRow label={t("gst.igst")} sub={t("gst.interState")} o={head.output.igst} i={head.input.igst} n={head.netPayable.igst} />
            <HeadRow label={t("gst.cgst")} sub={t("gst.central")} o={head.output.cgst} i={head.input.cgst} n={head.netPayable.cgst} />
            <HeadRow label={t("gst.sgst")} sub={t("gst.state")} o={head.output.sgst} i={head.input.sgst} n={head.netPayable.sgst} />
            <div className="flex flex-col gap-xs border-t border-hairline bg-surface-tint px-md py-sm sm:flex-row sm:items-center sm:gap-md">
              <span className="text-label-md uppercase tracking-wide text-muted sm:flex-1">{t("gst.total")}</span>
              <div className="flex items-center justify-between gap-sm sm:contents">
                <span className="text-body-sm font-semibold tabular-nums text-ink sm:w-24 sm:text-right">
                  {formatINR(r.outputTax)}
                </span>
                <span className="text-body-sm font-semibold tabular-nums text-ink sm:w-24 sm:text-right">
                  {formatINR(r.inputTax)}
                </span>
                <span className="text-body-md font-bold tabular-nums text-ink sm:w-24 sm:text-right">
                  {formatINR(r.netPayable)}
                </span>
              </div>
            </div>
          </div>
          <p className="mt-md text-body-sm text-subtle">
            {t("gst.headNote")}
          </p>
        </section>
      ) : null}

      {/* By rate — two columns fill the width */}
      <div className="grid grid-cols-1 gap-xxl lg:grid-cols-2">
        <RateBreakdown title={t("gst.outputByRate")} rows={r.outputByRate} empty={t("gst.noOutput")} />
        <RateBreakdown title={t("gst.inputByRate")} rows={r.inputByRate} empty={t("gst.noInput")} />
      </div>

      {/* Cess — only when there is any (separate ledger, not GST-creditable) */}
      {hasCess ? (
        <section className="max-w-form">
          <SectionHeading>{t("gst.cess")}</SectionHeading>
          <TotalRow label={t("gst.outputCess")} value={formatINR(outputCess)} strong />
          <TotalRow label={t("gst.inputCess")} value={`− ${formatINR(inputCess)}`} />
          <TotalRow label={t("gst.netCess")} value={formatINR(r.netCessPayable ?? 0)} strong big />
          <p className="mt-sm text-body-sm text-subtle">{t("gst.cessNote")}</p>
        </section>
      ) : null}

      {/* Returns note */}
      {returnedGst > 0 ? (
        <p className="text-body-sm text-subtle">
          {t("gst.returnsNote", { amount: formatINR(returnedGst) })}
        </p>
      ) : null}
    </div>
  );
}

/** One IGST/CGST/SGST head row in the GST head-wise split. Responsive like the
 *  products table: aligned columns on sm+, stacked with inline labels on phones. */
function HeadRow({ label, sub, o, i, n }: { label: string; sub: string; o: number; i: number; n: number }) {
  return (
    <div className="flex flex-col gap-xs border-b border-hairline px-md py-sm last:border-b-0 sm:flex-row sm:items-center sm:gap-md">
      <div className="min-w-0 sm:flex-1">
        <span className="text-body-md text-ink">{label}</span>
        <span className="ml-sm text-body-sm text-subtle">{sub}</span>
      </div>
      <div className="flex items-center justify-between gap-sm sm:contents">
        <span className="text-body-sm tabular-nums text-ink sm:w-24 sm:text-right">
          <span className="text-subtle sm:hidden">Output </span>
          {formatINR(o)}
        </span>
        <span className="text-body-sm tabular-nums text-muted sm:w-24 sm:text-right">
          <span className="text-subtle sm:hidden">ITC </span>
          {formatINR(i)}
        </span>
        <span className="text-body-md font-semibold tabular-nums text-ink sm:w-24 sm:text-right">
          <span className="text-subtle sm:hidden">Net </span>
          {formatINR(n)}
        </span>
      </div>
    </div>
  );
}

/** GST-by-rate breakdown — a clean Rate · Taxable · GST table with a total row,
 *  replacing the old single sparse line so the columns actually line up. */
function RateBreakdown({
  title,
  rows,
  empty,
}: {
  title: string;
  rows: { rate: number; taxable: number; tax: number }[];
  empty: string;
}) {
  const t = useTranslations("reports");
  const totalTaxable = rows.reduce((s, g) => s + g.taxable, 0);
  const totalTax = rows.reduce((s, g) => s + g.tax, 0);
  return (
    <section>
      <SectionHeading>{title}</SectionHeading>
      {rows.length === 0 ? (
        <EmptyHint>{empty}</EmptyHint>
      ) : (
        <div className="overflow-hidden rounded-md border border-hairline">
          <div className="flex items-center gap-md bg-surface-tint px-md py-sm">
            <span className="w-14 text-label-md uppercase tracking-wide text-muted">{t("gst.rateCol")}</span>
            <span className="flex-1 text-right text-label-md uppercase tracking-wide text-muted">
              {t("gst.taxableCol")}
            </span>
            <span className="w-28 text-right text-label-md uppercase tracking-wide text-muted">
              {t("gst.gstCol")}
            </span>
          </div>
          {rows.map((g, i) => (
            <div
              key={i}
              className="flex items-center gap-md border-b border-hairline px-md py-sm last:border-b-0"
            >
              <span className="w-14">
                <span className="inline-flex items-center rounded-full bg-surface-tint px-sm py-px text-body-sm font-semibold tabular-nums text-ink">
                  {g.rate}%
                </span>
              </span>
              <span className="flex-1 text-right text-body-sm tabular-nums text-muted">
                {formatINR(g.taxable)}
              </span>
              <span className="w-28 text-right text-body-sm font-semibold tabular-nums text-ink">
                {formatINR(g.tax)}
              </span>
            </div>
          ))}
          <div className="flex items-center gap-md border-t border-hairline bg-surface-tint px-md py-sm">
            <span className="w-14 text-label-md uppercase tracking-wide text-muted">{t("gst.total")}</span>
            <span className="flex-1 text-right text-body-sm font-semibold tabular-nums text-ink">
              {formatINR(totalTaxable)}
            </span>
            <span className="w-28 text-right text-body-md font-bold tabular-nums text-ink">
              {formatINR(totalTax)}
            </span>
          </div>
        </div>
      )}
    </section>
  );
}

function PnlView({ r, range }: { r: PnlReport; range: Range }) {
  const t = useTranslations("reports");
  // The headline figures are already netted (revenue net of returns, COGS net
  // of restocked returns). Add the netted-out parts back to show the gross
  // inputs each line is built from — that's the "proof" the table makes visible.
  const refunds = r.refunds ?? 0;
  const returnedCogs = r.returnedCogs ?? 0;
  const grossSales = r.revenue + refunds;
  const grossCogs = r.cogs + returnedCogs;
  const marginPct = (r.grossMargin * 100).toFixed(1);
  return (
    <div className="grid grid-cols-1 gap-xxxl lg:grid-cols-2 lg:gap-huge">
      {/* Left — the P&L statement and its proof. */}
      <div className="flex flex-col gap-xxl">
      <BigStat
        label={t("pnl.netProfit")}
        value={formatINR(r.netProfit)}
        tone={r.netProfit >= 0 ? "success" : "error"}
        hint={t("pnl.grossMarginHint", { pct: marginPct })}
      />
      <section className="max-w-form">
        <TotalRow label={t("pnl.revenue")} value={formatINR(r.revenue)} strong />
        <TotalRow label={t("pnl.cogs")} value={`− ${formatINR(r.cogs)}`} />
        <TotalRow label={t("pnl.grossProfit")} value={formatINR(r.grossProfit)} strong />
        <TotalRow label={t("pnl.writeoffs")} value={`− ${formatINR(r.writeoffs)}`} />
        <TotalRow label={t("pnl.netProfit")} value={formatINR(r.netProfit)} strong big />
      </section>

      {/* Proof: every headline figure traced back to the documents it sums. */}
      <section className="max-w-content">
        <SectionHeading>{t("pnl.howCalculated")}</SectionHeading>
        <table className="w-full border-collapse">
          <caption className="sr-only">
            {t("pnl.caption")}
          </caption>
          <tbody>
            <StatementRow
              label={t("pnl.confirmedSales")}
              basis={t("pnl.confirmedSalesBasis")}
              value={formatINR(grossSales)}
            />
            <StatementRow
              label={t("pnl.lessSalesReturns")}
              basis={t("pnl.lessSalesReturnsBasis")}
              value={`− ${formatINR(refunds)}`}
            />
            <StatementRow label={t("pnl.revenueA")} value={formatINR(r.revenue)} kind="subtotal" />

            <StatementRow
              label={t("pnl.goodsSoldCost")}
              basis={t("pnl.goodsSoldCostBasis")}
              value={formatINR(grossCogs)}
            />
            <StatementRow
              label={t("pnl.lessRestocked")}
              basis={t("pnl.lessRestockedBasis")}
              value={`− ${formatINR(returnedCogs)}`}
            />
            <StatementRow
              label={t("pnl.cogsB")}
              value={formatINR(r.cogs)}
              kind="subtotal"
            />

            <StatementRow
              label={t("pnl.grossProfitAB")}
              value={formatINR(r.grossProfit)}
              kind="subtotal"
            />
            <StatementRow
              label={t("pnl.lessWriteoffs")}
              basis={t("pnl.lessWriteoffsBasis")}
              value={`− ${formatINR(r.writeoffs)}`}
            />
            <StatementRow
              label={t("pnl.netProfitFormula")}
              value={formatINR(r.netProfit)}
              kind="total"
            />
          </tbody>
        </table>
        <p className="mt-md text-body-sm text-subtle">
          {t("pnl.proofNote", { pct: marginPct })}
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
  const t = useTranslations("reports");
  const [query, setQuery] = useState("");
  const [search, setSearch] = useState(""); // debounced value actually queried
  const [products, setProducts] = useState<SoldProduct[]>([]);
  const [total, setTotal] = useState(0);
  const [totals, setTotals] = useState({ salesCount: 0, totalQuantity: 0, totalAmount: 0 });
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState<string | null>(null);

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
        setError(e instanceof Error ? e.message : t("soldProducts.loadError"));
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
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
      setError(e instanceof Error ? e.message : t("soldProducts.loadMoreError"));
    } finally {
      setLoadingMore(false);
    }
  }

  const hasMore = products.length < total;
  const searching = query.trim().length > 0;

  return (
    <section>
      <div className="mb-md flex items-baseline justify-between gap-md">
        <SectionHeading>{t("soldProducts.title")}</SectionHeading>
        {!loading && total > 0 ? (
          <span className="shrink-0 text-body-sm tabular-nums text-subtle">
            {t("soldProducts.countOf", { shown: products.length, total })}
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
          placeholder={t("soldProducts.searchPlaceholder")}
          aria-label={t("soldProducts.searchAria")}
          className="h-10 w-full rounded-input border border-hairline bg-field pl-xxxl pr-huge text-body-md text-ink outline-none placeholder:text-subtle focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft"
        />
        {query ? (
          <button
            type="button"
            onClick={() => setQuery("")}
            aria-label={t("soldProducts.clearSearch")}
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
            ? t("soldProducts.noMatch", { query: query.trim() })
            : t("soldProducts.noneInRange")}
        </EmptyHint>
      ) : (
        <>
          <div className="overflow-hidden rounded-md border border-hairline">
            {/* Column header — only on sm+, where the columns line up. On mobile
                each row reflows into a card so the labels would be noise. */}
            <div className="hidden bg-surface-tint px-md py-sm sm:flex sm:items-center sm:gap-md">
              <span className="flex-1 text-label-md uppercase tracking-wide text-muted">
                {t("soldProducts.productCol")}
              </span>
              <span className="w-20 text-right text-label-md uppercase tracking-wide text-muted">
                {t("soldProducts.salesCol")}
              </span>
              <span className="w-20 text-right text-label-md uppercase tracking-wide text-muted">
                {t("soldProducts.qtyCol")}
              </span>
              <span className="w-24 text-right text-label-md uppercase tracking-wide text-muted">
                {t("soldProducts.amountCol")}
              </span>
            </div>
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
            {/* Grand-total footer — reflows the same way as the rows. */}
            <div className="flex flex-col gap-xs border-t border-hairline bg-surface-tint px-md py-sm sm:flex-row sm:items-center sm:gap-md">
              <span className="text-label-md uppercase tracking-wide text-muted sm:flex-1">
                {t("soldProducts.total")}
              </span>
              <div className="flex items-center justify-between gap-sm sm:contents">
                <span className="text-body-sm font-semibold tabular-nums text-ink sm:w-20 sm:text-right">
                  {t("soldProducts.salesCount", { count: totals.salesCount })}
                </span>
                <span className="text-body-sm font-semibold tabular-nums text-ink sm:w-20 sm:text-right">
                  {fmtQty(totals.totalQuantity)}
                </span>
                <span className="text-body-md font-bold tabular-nums text-ink sm:w-24 sm:text-right">
                  {formatINR(totals.totalAmount)}
                </span>
              </div>
            </div>
          </div>
          {hasMore ? (
            <button
              type="button"
              onClick={loadMore}
              disabled={loadingMore}
              className="mt-md inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:text-disabled"
            >
              {loadingMore ? t("common.loading") : t("soldProducts.loadMore", { left: total - products.length })}
            </button>
          ) : (
            <p className="mt-md text-body-sm text-subtle">
              {t("soldProducts.allShown", { total })}
            </p>
          )}
        </>
      )}
    </section>
  );
}

/**
 * One aggregated product row + its lazily-loaded sale timeline when expanded.
 * Responsive without a table: on sm+ it's an aligned row (product grows, the
 * three metrics are fixed-width columns via `sm:contents`); on phones it stacks
 * — the product name gets its own full-width line so it's always legible, with
 * the metrics on a second line below.
 */
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
  const t = useTranslations("reports");
  const tone = toneFor(product.productSku || product.productName || String(product.productId));
  const unit = product.unit ?? "";
  return (
    <div className="border-b border-hairline last:border-b-0">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={expanded}
        className={`flex w-full flex-col gap-sm px-md py-sm text-left transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brand-soft sm:flex-row sm:items-center sm:gap-md ${
          expanded ? "bg-surface-tint" : ""
        }`}
      >
        {/* Product — full width on mobile so the name is always readable */}
        <div className="flex min-w-0 items-center gap-sm sm:flex-1">
          <ChevronRight
            size={16}
            className={`shrink-0 text-muted transition-transform ${expanded ? "rotate-90" : ""}`}
          />
          <span className={`flex size-8 shrink-0 items-center justify-center rounded-md ${tone}`}>
            <Package size={16} />
          </span>
          <div className="min-w-0">
            <span className="block truncate text-body-md text-ink">
              {product.productName ?? t("common.product")}
            </span>
            {product.productSku ? (
              <span className="block truncate text-body-sm text-subtle">{product.productSku}</span>
            ) : null}
          </div>
        </div>

        {/* Metrics — a second line on mobile; aligned columns on sm+. The
            `sm:contents` wrappers collapse on desktop so each chip sits in its
            own fixed-width column lined up with the header. */}
        <div className="flex items-center justify-between gap-sm pl-7 sm:contents sm:pl-0">
          <span className="flex shrink-0 items-center sm:w-20 sm:justify-end">
            <span
              className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold tabular-nums ${countTone(product.salesCount)}`}
            >
              {t("soldProducts.salesCount", { count: product.salesCount })}
            </span>
          </span>
          <span className="flex shrink-0 items-center sm:w-20 sm:justify-end">
            <span
              className={`inline-flex items-center rounded-full px-sm py-px text-body-sm font-semibold tabular-nums ${qtyTone(product.totalQuantity)}`}
            >
              {fmtQty(product.totalQuantity)}
              {unit ? ` ${unit}` : ""}
            </span>
          </span>
          <span className="shrink-0 text-body-md font-semibold tabular-nums text-ink sm:w-24 sm:text-right">
            {formatINR(product.totalAmount)}
          </span>
        </div>
      </button>
      {expanded ? <ProductTimeline range={range} product={product} /> : null}
    </div>
  );
}

/** The drill-down: a single product's individual sales, newest first, loaded a
 *  page at a time only once the row is expanded. Rendered as a light timeline
 *  (not a nested grid) with a sticky product total at the bottom. */
function ProductTimeline({ range, product }: { range: Range; product: SoldProduct }) {
  const t = useTranslations("reports");
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
        setError(e instanceof Error ? e.message : t("timeline.loadError"));
        setItems([]);
        setTotal(0);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
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
      setError(e instanceof Error ? e.message : t("timeline.loadMoreError"));
    } finally {
      setLoadingMore(false);
    }
  }

  const hasMore = items.length < total;

  return (
    <div className="bg-surface px-md py-md sm:px-lg">
      {loading ? (
        <ListRowsSkeleton rows={3} leading={false} />
      ) : error ? (
        <p className="py-sm text-body-sm text-error">{error}</p>
      ) : items.length === 0 ? (
        <p className="py-sm text-body-sm text-subtle">{t("timeline.noSales")}</p>
      ) : (
        <ol className="flex flex-col gap-xs">
          {items.map((ev, i) => {
            const row = (
              <div className="flex items-center gap-sm rounded-md px-sm py-xs transition-colors hover:bg-surface-tint">
                <Clock size={14} className={`shrink-0 ${recencyColor(ev.soldAt)}`} />
                <span className="shrink-0 text-body-sm text-ink">{formatDateTime(ev.soldAt)}</span>
                {/* invoice no fills the gap on sm+; hidden on phones to keep the
                    row from overflowing */}
                <span className="hidden min-w-0 flex-1 truncate text-body-sm text-subtle sm:block">
                  {ev.invoiceNo ?? ""}
                </span>
                <span className="flex-1 sm:hidden" aria-hidden />
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
          {loadingMore ? t("common.loading") : t("timeline.loadMore", { left: total - items.length })}
        </button>
      ) : null}

      {!loading && !error ? (
        <div className="mt-sm flex items-center justify-between gap-md border-t border-hairline pt-sm">
          <span className="text-label-md uppercase tracking-wide text-subtle">
            {t("timeline.totalLine", { count: product.salesCount, qty: fmtQty(product.totalQuantity) })}
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

