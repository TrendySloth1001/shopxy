"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { BarChart3 } from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { todayInputDate } from "@/shared/datetime";
import { AnalyticsRangeProvider, useAnalyticsRange } from "@/features/analytics/range-context";
import { DatePicker } from "@/shared/ui/date-picker";

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
  const t = useTranslations("analytics");

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={BarChart3}
        tone="indigo"
        title={t("header.title")}
        subtitle={t("header.subtitle")}
      />

      {/* Tabs */}
      <div className="mt-lg flex flex-wrap items-center gap-sm">
        <Tab href="/dashboard/analytics" label={t("tabs.byProduct")} active={!onOverview} />
        <Tab href="/dashboard/analytics/insights" label={t("tabs.overview")} active={onOverview} />
      </div>

      {/* Sticky range toolbar — shared by both tabs */}
      <div className="sticky top-0 z-20 -mx-lg mt-md border-b border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <div className="flex flex-wrap items-end gap-md">
          <DateField label={t("range.from")} value={from} max={to} onChange={setFrom} />
          <DateField label={t("range.to")} value={to} min={from} max={todayInputDate()} onChange={setTo} />
          <div className="flex flex-wrap items-center gap-xs">
            <PresetChip label={t("range.last7Days")} onClick={() => preset("7d")} />
            <PresetChip label={t("range.last30Days")} onClick={() => preset("30d")} />
            <PresetChip label={t("range.thisMonth")} onClick={() => preset("month")} />
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
        active ? "bg-inverse-surface text-on-inverse" : "border border-hairline text-ink hover:bg-surface-tint"
      }`}
    >
      {label}
    </Link>
  );
}

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
