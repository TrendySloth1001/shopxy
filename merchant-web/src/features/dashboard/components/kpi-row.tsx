import Link from "next/link";
import { ArrowDownLeft, ArrowUpRight, IndianRupee, TrendingUp } from "lucide-react";
import type { DashboardKpis, DashboardPeriod } from "../stats";
import { DeltaChip, inr } from "./ui";

/**
 * Hero KPI row — the 5-second money story, importance left→right: what you sold,
 * what you kept, what you're owed, what you owe. Each card is a link to the
 * relevant screen with a descriptive aria-label; Sales/Profit carry a delta vs
 * the previous equal window, balances carry a debtor/creditor count.
 */
export function KpiRow({ kpis, period }: { kpis: DashboardKpis; period: DashboardPeriod }) {
  return (
    <div className="grid grid-cols-2 gap-md lg:grid-cols-4">
      <KpiCard
        href="/dashboard/reports"
        icon={<IndianRupee size={16} className="text-brand-strong" aria-hidden="true" />}
        label="Sales"
        value={inr.format(kpis.sales.value)}
        ariaLabel={`Sales ${inr.format(kpis.sales.value)} for the selected period`}
        footer={<DeltaChip value={kpis.sales.deltaPct} period={period} />}
      />
      <KpiCard
        href="/dashboard/reports"
        icon={<TrendingUp size={16} className="text-success" aria-hidden="true" />}
        label="Net profit"
        value={inr.format(kpis.profit.value)}
        ariaLabel={`Net profit ${inr.format(kpis.profit.value)}, margin ${kpis.profit.margin} percent`}
        footer={
          <div className="flex items-center gap-sm">
            <DeltaChip value={kpis.profit.deltaPct} period={period} />
            <span className="text-label-md text-muted">{kpis.profit.margin}% margin</span>
          </div>
        }
      />
      <KpiCard
        href="/dashboard/parties"
        icon={<ArrowDownLeft size={16} className="text-accent-indigo" aria-hidden="true" />}
        label="Receivables"
        value={inr.format(kpis.receivables.outstanding)}
        ariaLabel={`Receivables ${inr.format(kpis.receivables.outstanding)} from ${kpis.receivables.debtors} parties`}
        footer={
          <span className="text-label-md text-muted">
            {kpis.receivables.debtors} {kpis.receivables.debtors === 1 ? "party owes you" : "parties owe you"}
          </span>
        }
      />
      <KpiCard
        href="/dashboard/vendors"
        icon={<ArrowUpRight size={16} className="text-accent-amber" aria-hidden="true" />}
        label="Payables"
        value={inr.format(kpis.payables.outstanding)}
        ariaLabel={`Payables ${inr.format(kpis.payables.outstanding)} to ${kpis.payables.creditors} vendors`}
        footer={
          <span className="text-label-md text-muted">
            {kpis.payables.creditors} {kpis.payables.creditors === 1 ? "vendor to pay" : "vendors to pay"}
          </span>
        }
      />
    </div>
  );
}

function KpiCard({
  href,
  icon,
  label,
  value,
  ariaLabel,
  footer,
}: {
  href: string;
  icon: React.ReactNode;
  label: string;
  value: string;
  ariaLabel: string;
  footer: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      aria-label={ariaLabel}
      className="group flex min-h-[7rem] flex-col justify-between rounded-lg border border-hairline bg-canvas p-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <div className="flex items-center gap-sm">
        {icon}
        <span className="text-label-md text-muted">{label}</span>
      </div>
      <p className="mt-sm text-headline-md tabular-nums text-ink">{value}</p>
      <div className="mt-sm">{footer}</div>
    </Link>
  );
}
