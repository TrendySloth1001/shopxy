"use client";

import { useRef } from "react";
import { PERIODS, PERIOD_LABEL, type DashboardPeriod } from "../stats";

/**
 * Accessible segmented control for the dashboard window. Implemented as a
 * radiogroup: arrow keys move (and select) between options, the selected option
 * is the only tab stop, and each control shows a token focus ring.
 */
export function PeriodSwitcher({
  value,
  onChange,
}: {
  value: DashboardPeriod;
  onChange: (p: DashboardPeriod) => void;
}) {
  const refs = useRef<(HTMLButtonElement | null)[]>([]);

  function onKeyDown(e: React.KeyboardEvent, index: number) {
    let next = index;
    if (e.key === "ArrowRight" || e.key === "ArrowDown") next = (index + 1) % PERIODS.length;
    else if (e.key === "ArrowLeft" || e.key === "ArrowUp") next = (index - 1 + PERIODS.length) % PERIODS.length;
    else return;
    e.preventDefault();
    onChange(PERIODS[next]);
    refs.current[next]?.focus();
  }

  return (
    <div
      role="radiogroup"
      aria-label="Dashboard time period"
      className="inline-flex items-center gap-[2px] rounded-button border border-hairline bg-canvas p-[2px]"
    >
      {PERIODS.map((p, i) => {
        const selected = p === value;
        return (
          <button
            key={p}
            ref={(el) => {
              refs.current[i] = el;
            }}
            type="button"
            role="radio"
            aria-checked={selected}
            tabIndex={selected ? 0 : -1}
            onClick={() => onChange(p)}
            onKeyDown={(e) => onKeyDown(e, i)}
            className={`rounded-[6px] px-md py-xs text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
              selected ? "bg-ink text-white" : "text-muted hover:text-ink hover:bg-surface-tint"
            }`}
          >
            {PERIOD_LABEL[p]}
          </button>
        );
      })}
    </div>
  );
}
