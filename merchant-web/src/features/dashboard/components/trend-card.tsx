"use client";

import { useTranslations } from "next-intl";
import type { DashboardTrend } from "../stats";
import { inr } from "./ui";
import { TrendChart, type TrendSeries } from "./trend-chart";

const inrCompact = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  notation: "compact",
  maximumFractionDigits: 1,
});

function fmtDay(key: string): string {
  const d = new Date(`${key}T00:00:00`);
  if (Number.isNaN(d.getTime())) return key;
  return d.toLocaleDateString("en-IN", { day: "numeric", month: "short" });
}

// Distinct token colours for each payment mode line.
const MODE_COLOR: Record<string, { stroke: string; dot: string }> = {
  UPI: { stroke: "text-accent-teal", dot: "bg-accent-teal" },
  CASH: { stroke: "text-success", dot: "bg-success" },
  CARD: { stroke: "text-accent-indigo", dot: "bg-accent-indigo" },
  NEFT: { stroke: "text-accent-amber", dot: "bg-accent-amber" },
  RTGS: { stroke: "text-accent-rose", dot: "bg-accent-rose" },
  CHEQUE: { stroke: "text-brand", dot: "bg-brand" },
};
const MODE_FALLBACK = { stroke: "text-subtle", dot: "bg-subtle" };
const titleCase = (m: string) => m.charAt(0) + m.slice(1).toLowerCase();

/**
 * Sales trend with comparison lines (previous period, purchases, returns) and a
 * line per payment mode (cash / UPI / card …). Sales + the payment-mode lines
 * show by default; the comparison lines start hidden and can be toggled on.
 */
export function TrendCard({ trend, className = "" }: { trend: DashboardTrend; className?: string }) {
  const t = useTranslations("dashboard");
  const labels = trend.labels.map(fmtDay);
  const total = trend.sales.reduce((s, v) => s + v, 0);

  const series: TrendSeries[] = [
    { key: "sales", label: t("trend.sales"), stroke: "text-brand", dot: "bg-brand", values: trend.sales },
    ...trend.paymentSeries.map((p) => {
      const c = MODE_COLOR[p.mode.toUpperCase()] ?? MODE_FALLBACK;
      return { key: `pay:${p.mode}`, label: titleCase(p.mode), stroke: c.stroke, dot: c.dot, values: p.values };
    }),
  ];

  // Comparison lines — included but hidden by default (toggle on demand).
  const comparisons: TrendSeries[] = [];
  if (trend.previous.some((v) => v !== 0))
    comparisons.push({ key: "previous", label: t("trend.previous"), stroke: "text-subtle", dot: "bg-subtle", values: trend.previous });
  if (trend.purchases.some((v) => v !== 0))
    comparisons.push({ key: "purchases", label: t("trend.purchases"), stroke: "text-accent-amber", dot: "bg-accent-amber", values: trend.purchases });
  if (trend.returns.some((v) => v !== 0))
    comparisons.push({ key: "returns", label: t("trend.returns"), stroke: "text-accent-rose", dot: "bg-accent-rose", values: trend.returns });

  const all = [...series, ...comparisons];

  return (
    <section aria-labelledby="trend-h" className={`rounded-lg border border-hairline bg-canvas p-md ${className}`}>
      <div className="flex flex-wrap items-end justify-between gap-md">
        <div>
          <h2 id="trend-h" className="text-label-md uppercase tracking-wide text-muted">
            {t("trend.title")}
          </h2>
          <p className="mt-xs text-title-md tabular-nums text-ink">{inr.format(total)}</p>
        </div>
      </div>

      <div className="mt-md">
        <TrendChart
          series={all}
          xLabels={labels}
          ariaLabel={t("trend.ariaLabel", { days: labels.length })}
          formatValue={(v) => inr.format(v)}
          formatTick={(v) => inrCompact.format(v)}
          initialHidden={comparisons.map((c) => c.key)}
        />
      </div>

      {/* Screen-reader data-table fallback for the chart. */}
      <table className="sr-only">
        <caption>{t("trend.tableCaption")}</caption>
        <thead>
          <tr>
            <th scope="col">{t("trend.day")}</th>
            {all.map((s) => (
              <th key={s.key} scope="col">
                {s.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {labels.map((lbl, i) => (
            <tr key={lbl + i}>
              <th scope="row">{lbl}</th>
              {all.map((s) => (
                <td key={s.key}>{inr.format(s.values[i] ?? 0)}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
