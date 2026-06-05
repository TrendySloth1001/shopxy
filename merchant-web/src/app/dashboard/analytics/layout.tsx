"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { BarChart3 } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { todayInputDate } from "@/shared/datetime";
import { AnalyticsRangeProvider, useAnalyticsRange } from "@/features/analytics/range-context";

export default function AnalyticsLayout({ children }: { children: ReactNode }) {
  return (
    <AnalyticsRangeProvider>
      <Shell>{children}</Shell>
    </AnalyticsRangeProvider>
  );
}

function Shell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const onOverview = pathname.startsWith("/dashboard/analytics/insights");
  const { from, to, setFrom, setTo, preset } = useAnalyticsRange();

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={BarChart3}
        tone="indigo"
        title="Analytics"
        subtitle="How customers engage with your products — the funnel and trends, and the per-product numbers."
      />

      {/* Tabs */}
      <div className="mt-lg flex flex-wrap items-center gap-sm">
        <Tab href="/dashboard/analytics" label="By product" active={!onOverview} />
        <Tab href="/dashboard/analytics/insights" label="Overview" active={onOverview} />
      </div>

      {/* Sticky range toolbar — shared by both tabs */}
      <div className="sticky top-0 z-20 -mx-lg mt-md border-b border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <div className="flex flex-wrap items-end gap-md">
          <DateField label="From" value={from} max={to} onChange={setFrom} />
          <DateField label="To" value={to} min={from} max={todayInputDate()} onChange={setTo} />
          <div className="flex flex-wrap items-center gap-xs">
            <PresetChip label="Last 7 days" onClick={() => preset("7d")} />
            <PresetChip label="Last 30 days" onClick={() => preset("30d")} />
            <PresetChip label="This month" onClick={() => preset("month")} />
          </div>
        </div>
      </div>

      {children}
    </div>
  );
}

function Tab({ href, label, active }: { href: string; label: string; active: boolean }) {
  return (
    <Link
      href={href}
      aria-current={active ? "page" : undefined}
      className={`inline-flex h-9 items-center rounded-button px-md text-label-md transition-colors ${
        active ? "bg-ink text-white" : "border border-hairline text-ink hover:bg-surface-tint"
      }`}
    >
      {label}
    </Link>
  );
}

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
