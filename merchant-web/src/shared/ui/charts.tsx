"use client";

import { useState } from "react";

/**
 * Lightweight, dependency-free SVG charts in the token palette. The stroke uses
 * `currentColor` (set a `text-*` class) with a non-scaling stroke so the line
 * stays crisp while the SVG stretches to fill its container. Heights come from a
 * Tailwind class, not inline pixels.
 */

export type ChartPoint = { label: string; value: number };

const clamp = (n: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, n));

/**
 * Interactive filled line chart. Hovering shows a guide line, a marker on the
 * nearest point and a tooltip with that point's label + value. `overlay` (e.g. a
 * moving average) draws as a muted dashed line behind the primary series.
 */
export function LineChart({
  points,
  overlay,
  heightClass = "h-32",
  ariaLabel,
  formatValue = (n) => String(Math.round(n)),
}: {
  points: ChartPoint[];
  overlay?: number[];
  heightClass?: string;
  ariaLabel?: string;
  formatValue?: (n: number) => string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  if (points.length === 0) return null;

  const n = points.length;
  const values = points.map((p) => p.value);
  const max = Math.max(...values, ...(overlay ?? []), 1);
  const xOf = (i: number) => (n === 1 ? 0 : (i / (n - 1)) * 100);
  const yOf = (v: number) => 100 - (v / max) * 100;

  const linePts =
    n === 1
      ? `0,${yOf(values[0])} 100,${yOf(values[0])}`
      : points.map((p, i) => `${xOf(i)},${yOf(p.value)}`).join(" ");
  const areaPts = `0,100 ${linePts} 100,100`;
  const showDots = n <= 31;

  function onMove(e: React.MouseEvent<HTMLDivElement>) {
    const rect = e.currentTarget.getBoundingClientRect();
    if (rect.width === 0) return;
    const x = (e.clientX - rect.left) / rect.width;
    setHover(clamp(Math.round(x * (n - 1)), 0, n - 1));
  }

  const hv = hover != null ? points[hover] : null;

  return (
    <div className="relative w-full" onMouseMove={onMove} onMouseLeave={() => setHover(null)}>
      <svg
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        role="img"
        aria-label={ariaLabel}
        className={`w-full text-brand ${heightClass}`}
      >
        <polygon points={areaPts} fill="currentColor" fillOpacity={0.1} stroke="none" />
        {overlay && overlay.length > 0 ? (
          <polyline
            points={overlay.map((v, i) => `${xOf(i)},${yOf(v)}`).join(" ")}
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            strokeDasharray="3 3"
            vectorEffect="non-scaling-stroke"
            className="text-subtle"
          />
        ) : null}
        <polyline
          points={linePts}
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          strokeLinejoin="round"
          strokeLinecap="round"
          vectorEffect="non-scaling-stroke"
        />
      </svg>

      {/* point markers (only when sparse enough to read) */}
      {showDots
        ? points.map((p, i) => (
            <span
              key={i}
              className="pointer-events-none absolute size-1.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-brand"
              style={{ left: `${xOf(i)}%`, top: `${yOf(p.value)}%` }}
            />
          ))
        : null}

      {/* hover affordances */}
      {hv ? (
        <>
          <span
            className="pointer-events-none absolute bottom-0 top-0 w-px bg-hairline"
            style={{ left: `${xOf(hover!)}%` }}
          />
          <span
            className="pointer-events-none absolute size-2.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-brand ring-2 ring-canvas"
            style={{ left: `${xOf(hover!)}%`, top: `${yOf(hv.value)}%` }}
          />
          <div
            className="pointer-events-none absolute z-10 -translate-x-1/2 -translate-y-[140%] whitespace-nowrap rounded-md bg-ink px-sm py-xs text-center shadow-floating"
            style={{ left: `${clamp(xOf(hover!), 10, 90)}%`, top: `${yOf(hv.value)}%` }}
          >
            <span className="block text-body-sm font-semibold text-white">{formatValue(hv.value)}</span>
            <span className="block text-body-sm text-white/70">{hv.label}</span>
          </div>
        </>
      ) : null}
    </div>
  );
}
