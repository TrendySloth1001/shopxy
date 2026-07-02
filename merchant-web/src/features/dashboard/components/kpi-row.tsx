"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { ArrowDownLeft, ArrowUpRight, IndianRupee, TrendingUp } from "lucide-react";
import type { Range } from "@/features/reports/api";
import type { DashboardKpis, DashboardPeriod } from "../stats";
import { DeltaChip, inr } from "./ui";
import { KpiDrawer, type KpiDrawerKind } from "./kpi-drawers";

/**
 * Hero KPI row — the 5-second money story, importance left→right: what you sold,
 * what you kept, what you're owed, what you owe. Each card opens a drill-down
 * slide-over: Sales → products sold (filterable), Net profit → the traced
 * calculation, Receivables/Payables → debtors/creditors, each expandable to the
 * documents behind the balance. Sales/Profit carry a delta vs the previous equal
 * window; balances carry a debtor/creditor count.
 */
export function KpiRow({
  kpis,
  period,
  range,
}: {
  kpis: DashboardKpis;
  period: DashboardPeriod;
  range: Range;
}) {
  const t = useTranslations("dashboard");
  const [open, setOpen] = useState<KpiDrawerKind | null>(null);

  return (
    <>
      <div className="grid grid-cols-2 gap-md lg:grid-cols-4">
        <KpiCard
          onClick={() => setOpen("sales")}
          icon={<IndianRupee size={16} className="text-brand-strong" aria-hidden="true" />}
          label={t("kpi.sales")}
          value={inr.format(kpis.sales.value)}
          ariaLabel={t("kpi.salesAria", { value: inr.format(kpis.sales.value) })}
          footer={<DeltaChip value={kpis.sales.deltaPct} period={period} />}
        />
        <KpiCard
          onClick={() => setOpen("profit")}
          icon={<TrendingUp size={16} className="text-success" aria-hidden="true" />}
          label={t("kpi.netProfit")}
          value={inr.format(kpis.profit.value)}
          ariaLabel={t("kpi.netProfitAria", { value: inr.format(kpis.profit.value), margin: kpis.profit.margin })}
          footer={
            <div className="flex items-center gap-sm">
              <DeltaChip value={kpis.profit.deltaPct} period={period} />
              <span className="text-label-md text-muted">{t("kpi.margin", { margin: kpis.profit.margin })}</span>
            </div>
          }
        />
        <KpiCard
          onClick={() => setOpen("receivables")}
          icon={<ArrowDownLeft size={16} className="text-accent-indigo" aria-hidden="true" />}
          label={t("kpi.receivables")}
          value={inr.format(kpis.receivables.outstanding)}
          ariaLabel={t("kpi.receivablesAria", { value: inr.format(kpis.receivables.outstanding), count: kpis.receivables.debtors })}
          footer={
            <span className="text-label-md text-muted">
              {t("kpi.debtors", { count: kpis.receivables.debtors })}
            </span>
          }
        />
        <KpiCard
          onClick={() => setOpen("payables")}
          icon={<ArrowUpRight size={16} className="text-accent-amber" aria-hidden="true" />}
          label={t("kpi.payables")}
          value={inr.format(kpis.payables.outstanding)}
          ariaLabel={t("kpi.payablesAria", { value: inr.format(kpis.payables.outstanding), count: kpis.payables.creditors })}
          footer={
            <span className="text-label-md text-muted">
              {t("kpi.creditors", { count: kpis.payables.creditors })}
            </span>
          }
        />
      </div>

      {open ? <KpiDrawer kind={open} range={range} onClose={() => setOpen(null)} /> : null}
    </>
  );
}

function KpiCard({
  onClick,
  icon,
  label,
  value,
  ariaLabel,
  footer,
}: {
  onClick: () => void;
  icon: React.ReactNode;
  label: string;
  value: string;
  ariaLabel: string;
  footer: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={ariaLabel}
      aria-haspopup="dialog"
      className="group flex min-h-[7rem] flex-col justify-between rounded-lg border border-hairline bg-canvas p-md text-left transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <div className="flex items-center gap-sm">
        {icon}
        <span className="text-label-md text-muted">{label}</span>
      </div>
      <p className="mt-sm text-headline-md tabular-nums text-ink">{value}</p>
      <div className="mt-sm">{footer}</div>
    </button>
  );
}
