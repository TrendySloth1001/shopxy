import Link from "next/link";
import { ArrowDown, ArrowUp } from "lucide-react";
import type { DashboardPeriod } from "../stats";

/** INR formatters shared across the dashboard. */
export const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});
export const inr2 = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  minimumFractionDigits: 2,
});

const PERIOD_PHRASE: Record<DashboardPeriod, string> = {
  today: "the previous day",
  week: "the previous 7 days",
  month: "the previous 30 days",
};

/** Small uppercase section eyebrow. */
export function Eyebrow({ children }: { children: React.ReactNode }) {
  return <p className="text-label-md uppercase tracking-wide text-muted">{children}</p>;
}

/**
 * A labelled section landmark with a heading and an optional action link. The
 * heading is wired to the section via `aria-labelledby` for screen readers.
 */
export function Section({
  id,
  title,
  action,
  children,
  className = "",
}: {
  id: string;
  title: string;
  action?: { label: string; href: string };
  children: React.ReactNode;
  className?: string;
}) {
  const headingId = `${id}-h`;
  return (
    <section aria-labelledby={headingId} className={className}>
      <div className="flex items-center justify-between gap-md">
        <h2 id={headingId} className="text-label-md uppercase tracking-wide text-muted">
          {title}
        </h2>
        {action ? (
          <Link
            href={action.href}
            className="rounded-xs text-label-md text-brand-strong underline-offset-2 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            {action.label}
          </Link>
        ) : null}
      </div>
      <div className="mt-md">{children}</div>
    </section>
  );
}

/**
 * Period-over-period delta chip. Colour is paired with an arrow icon and a sign
 * (never colour alone, per WCAG) and carries a full text alternative. `null`
 * delta (no prior base) renders a neutral "New" chip.
 */
export function DeltaChip({ value, period }: { value: number | null; period: DashboardPeriod }) {
  if (value === null) {
    return (
      <span className="inline-flex items-center rounded-full bg-surface-tint px-sm py-[2px] text-label-md text-muted">
        New
      </span>
    );
  }
  const up = value > 0;
  const flat = value === 0;
  const tone = flat
    ? "bg-surface-tint text-muted"
    : up
      ? "bg-success-soft text-success"
      : "bg-error-soft text-error";
  const Icon = up ? ArrowUp : ArrowDown;
  const label = flat
    ? `No change versus ${PERIOD_PHRASE[period]}`
    : `${up ? "Up" : "Down"} ${Math.abs(value)} percent versus ${PERIOD_PHRASE[period]}`;
  return (
    <span
      className={`inline-flex items-center gap-[2px] rounded-full px-sm py-[2px] text-label-md tabular-nums ${tone}`}
      aria-label={label}
    >
      {!flat ? <Icon size={12} aria-hidden="true" /> : null}
      {up ? "+" : flat ? "" : "−"}
      {Math.abs(value)}%
    </span>
  );
}
