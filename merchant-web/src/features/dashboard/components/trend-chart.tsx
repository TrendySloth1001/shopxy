"use client";

import { useMemo, useState } from "react";

/**
 * Rich multi-series trend chart (smooth curves, gridlines, axis labels,
 * toggleable legend, floating tooltip + crosshair) in the token palette. Lines
 * live in a stretched SVG (non-scaling stroke keeps them crisp); gridlines,
 * axis labels, markers and the tooltip are HTML overlays positioned by percent
 * so text stays sharp at any width. Accessible: role=img + aria-label, with the
 * caller providing an sr-only data table.
 */

export type TrendSeries = {
  key: string;
  label: string;
  /** Tailwind text-* class → drives the line colour via currentColor. */
  stroke: string;
  /** Tailwind bg-* class → the legend/marker dot. */
  dot: string;
  values: number[];
};

const clamp = (n: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, n));

/** Catmull-Rom → cubic-bezier smoothing over points in the 0–100 plot space. */
function smoothPath(pts: { x: number; y: number }[]): string {
  if (pts.length === 0) return "";
  if (pts.length === 1) return `M0,${pts[0].y} L100,${pts[0].y}`;
  let d = `M${pts[0].x},${pts[0].y}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] ?? pts[i];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[i + 2] ?? p2;
    const c1x = p1.x + (p2.x - p0.x) / 6;
    const c1y = p1.y + (p2.y - p0.y) / 6;
    const c2x = p2.x - (p3.x - p1.x) / 6;
    const c2y = p2.y - (p3.y - p1.y) / 6;
    d += ` C${c1x.toFixed(2)},${c1y.toFixed(2)} ${c2x.toFixed(2)},${c2y.toFixed(2)} ${p2.x},${p2.y}`;
  }
  return d;
}

export function TrendChart({
  series,
  xLabels,
  ariaLabel,
  formatValue = (n) => String(Math.round(n)),
  formatTick = (n) => String(Math.round(n)),
  initialHidden = [],
}: {
  series: TrendSeries[];
  xLabels: string[];
  ariaLabel?: string;
  formatValue?: (n: number) => string;
  formatTick?: (n: number) => string;
  initialHidden?: string[];
}) {
  const [hidden, setHidden] = useState<Set<string>>(() => new Set(initialHidden));
  const [hover, setHover] = useState<number | null>(null);

  const visible = series.filter((s) => !hidden.has(s.key));
  const n = xLabels.length;

  const max = useMemo(() => {
    const vals = visible.flatMap((s) => s.values);
    return Math.max(...vals, 1);
  }, [visible]);

  const xOf = (i: number) => (n <= 1 ? 0 : (i / (n - 1)) * 100);
  const yOf = (v: number) => 100 - (v / max) * 100;

  const ticks = [0, 0.25, 0.5, 0.75, 1].map((t) => t * max);
  const xStep = Math.max(1, Math.ceil(n / 7));

  function toggle(key: string) {
    setHidden((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      // keep at least one series visible
      else if (series.length - next.size > 1) next.add(key);
      return next;
    });
  }

  function onMove(e: React.MouseEvent<HTMLDivElement>) {
    const rect = e.currentTarget.getBoundingClientRect();
    if (rect.width === 0 || n <= 1) return;
    const x = (e.clientX - rect.left) / rect.width;
    setHover(clamp(Math.round(x * (n - 1)), 0, n - 1));
  }

  return (
    <div>
      {/* toggle legend */}
      <div className="flex flex-wrap items-center gap-sm">
        {series.map((s) => {
          const on = !hidden.has(s.key);
          return (
            <button
              key={s.key}
              type="button"
              aria-pressed={on}
              onClick={() => toggle(s.key)}
              className={`inline-flex items-center gap-xs rounded-full border px-md py-xs text-label-md transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft ${
                on ? "border-hairline text-ink" : "border-hairline text-subtle"
              }`}
            >
              <span className={`size-2 rounded-full ${s.dot} ${on ? "" : "opacity-40"}`} aria-hidden="true" />
              {s.label}
            </button>
          );
        })}
      </div>

      {/* plot */}
      <div className="mt-md flex gap-sm">
        {/* y axis labels */}
        <div className="relative w-10 shrink-0">
          <div className="relative h-72">
            {ticks
              .slice()
              .reverse()
              .map((t, i) => (
                <span
                  key={i}
                  className="absolute right-0 -translate-y-1/2 text-[11px] tabular-nums text-subtle"
                  style={{ top: `${(i / (ticks.length - 1)) * 100}%` }}
                >
                  {formatTick(t)}
                </span>
              ))}
          </div>
        </div>

        <div className="min-w-0 flex-1">
          <div
            className="relative h-72 w-full"
            role="img"
            aria-label={ariaLabel}
            onMouseMove={onMove}
            onMouseLeave={() => setHover(null)}
          >
            {/* gridlines */}
            {ticks.map((_, i) => (
              <span
                key={i}
                className="pointer-events-none absolute inset-x-0 border-t border-hairline"
                style={{ top: `${(i / (ticks.length - 1)) * 100}%` }}
              />
            ))}

            {/* lines */}
            <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="absolute inset-0 size-full overflow-visible">
              {visible.map((s) => (
                <path
                  key={s.key}
                  d={smoothPath(s.values.map((v, i) => ({ x: xOf(i), y: yOf(v) })))}
                  fill="none"
                  stroke="currentColor"
                  strokeWidth={2.5}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  vectorEffect="non-scaling-stroke"
                  className={s.stroke}
                />
              ))}
            </svg>

            {/* crosshair + markers + tooltip */}
            {hover != null ? (
              <>
                <span
                  className="pointer-events-none absolute bottom-0 top-0 border-l border-dashed border-subtle"
                  style={{ left: `${xOf(hover)}%` }}
                  aria-hidden="true"
                />
                {visible.map((s) => (
                  <span
                    key={s.key}
                    className={`pointer-events-none absolute size-2.5 -translate-x-1/2 -translate-y-1/2 rounded-full ring-2 ring-canvas ${s.dot}`}
                    style={{ left: `${xOf(hover)}%`, top: `${yOf(s.values[hover] ?? 0)}%` }}
                    aria-hidden="true"
                  />
                ))}
                {/* Sit beside the crosshair (on whichever side has room) with a
                    gap, so the card stays near the point without covering the
                    lines being inspected. */}
                <div
                  className="pointer-events-none absolute top-1 z-10 w-max max-w-[45%] rounded-lg border border-hairline bg-canvas px-md py-sm shadow-floating"
                  style={
                    xOf(hover) < 50
                      ? { left: `calc(${xOf(hover)}% + 12px)` }
                      : { right: `calc(${100 - xOf(hover)}% + 12px)` }
                  }
                >
                  <p className="text-label-md text-muted">{xLabels[hover]}</p>
                  <ul className="mt-xs space-y-[2px]">
                    {visible.map((s) => (
                      <li key={s.key} className="flex items-center gap-sm text-body-sm">
                        <span className={`size-2 shrink-0 rounded-full ${s.dot}`} aria-hidden="true" />
                        <span className="tabular-nums text-ink">{formatValue(s.values[hover] ?? 0)}</span>
                        <span className="text-muted">{s.label}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </>
            ) : null}
          </div>

          {/* x axis labels */}
          <div className="relative mt-xs h-4">
            {xLabels.map((lbl, i) =>
              i % xStep === 0 || i === n - 1 ? (
                <span
                  key={i}
                  className="absolute -translate-x-1/2 text-[11px] text-subtle"
                  style={{ left: `${clamp(xOf(i), 4, 96)}%` }}
                >
                  {lbl}
                </span>
              ) : null,
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
