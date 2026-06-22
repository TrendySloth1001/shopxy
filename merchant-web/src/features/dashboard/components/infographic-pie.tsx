"use client";

import { useState } from "react";

/**
 * Infographic-style pie: variable-radius wedges (bigger value → reaches further
 * out), gaps between slices, a % label on each slice, a dark centre hub, and
 * leader-line callouts. Pure SVG in the token palette; accessible via role=img +
 * aria-label and an sr-only data table. Slices beyond the palette length are
 * grouped as "Other".
 *
 * Right side carries a written summary of the whole chart (with emphasised
 * numbers/names). Hovering (or keyboard-focusing) a slice highlights it and
 * slides in that slice's detail at the bottom.
 */

export type PieRow = { label: string; value: number };
export type PieSwatch = { text: string; bg: string };

export const PIE_PALETTE_A: PieSwatch[] = [
  { text: "text-brand", bg: "bg-brand" },
  { text: "text-accent-indigo", bg: "bg-accent-indigo" },
  { text: "text-accent-amber", bg: "bg-accent-amber" },
  { text: "text-success", bg: "bg-success" },
  { text: "text-accent-teal", bg: "bg-accent-teal" },
  { text: "text-accent-rose", bg: "bg-accent-rose" },
];
export const PIE_PALETTE_B: PieSwatch[] = [
  { text: "text-accent-teal", bg: "bg-accent-teal" },
  { text: "text-accent-rose", bg: "bg-accent-rose" },
  { text: "text-brand", bg: "bg-brand" },
  { text: "text-accent-amber", bg: "bg-accent-amber" },
  { text: "text-accent-indigo", bg: "bg-accent-indigo" },
  { text: "text-success", bg: "bg-success" },
];
export const PIE_PALETTE_C: PieSwatch[] = [
  { text: "text-accent-amber", bg: "bg-accent-amber" },
  { text: "text-accent-rose", bg: "bg-accent-rose" },
  { text: "text-accent-indigo", bg: "bg-accent-indigo" },
  { text: "text-brand", bg: "bg-brand" },
  { text: "text-success", bg: "bg-success" },
  { text: "text-accent-teal", bg: "bg-accent-teal" },
];

// Geometry (SVG user units). Tighter viewBox + larger radii so the pie fills
// more of the frame (callouts still sit inside it).
const W = 760;
const H = 470;
const CX = W / 2;
const CY = H / 2;
const HUB = 70;
const R_MIN = 150;
const R_MAX = 188;
const GAP_DEG = 3;
const STUB = 28;
const EXPLODE = 12; // how far the hovered slice lifts out (smoothly, via CSS transform)

function polar(r: number, angleDeg: number): [number, number] {
  const a = ((angleDeg - 90) * Math.PI) / 180;
  return [CX + r * Math.cos(a), CY + r * Math.sin(a)];
}
function unit(angleDeg: number): [number, number] {
  const a = ((angleDeg - 90) * Math.PI) / 180;
  return [Math.cos(a), Math.sin(a)];
}
function sector(rInner: number, rOuter: number, start: number, end: number): string {
  const [x1, y1] = polar(rOuter, start);
  const [x2, y2] = polar(rOuter, end);
  const [x3, y3] = polar(rInner, end);
  const [x4, y4] = polar(rInner, start);
  const large = end - start > 180 ? 1 : 0;
  return `M${x1},${y1} A${rOuter},${rOuter} 0 ${large} 1 ${x2},${y2} L${x3},${y3} A${rInner},${rInner} 0 ${large} 0 ${x4},${y4} Z`;
}
function collapse(rows: PieRow[], maxSlices: number): PieRow[] {
  const sorted = rows.filter((r) => r.value > 0).sort((a, b) => b.value - a.value);
  if (sorted.length <= maxSlices) return sorted;
  const head = sorted.slice(0, maxSlices - 1);
  head.push({ label: "Other", value: sorted.slice(maxSlices - 1).reduce((s, r) => s + r.value, 0) });
  return head;
}
const trim = (s: string, n = 18) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

export function InfographicPie({
  rows,
  palette,
  formatValue,
  ariaLabel,
  subject = "the total",
  itemNoun = "items",
}: {
  rows: PieRow[];
  palette: PieSwatch[];
  formatValue: (n: number) => string;
  ariaLabel: string;
  subject?: string;
  itemNoun?: string;
}) {
  const [active, setActive] = useState<number | null>(null);

  const slices = collapse(rows, palette.length);
  const total = slices.reduce((s, r) => s + r.value, 0);
  if (total <= 0) return <p className="text-body-sm text-muted">No data in this period yet.</p>;

  const maxVal = Math.max(...slices.map((s) => s.value));
  const single = slices.length === 1;
  const sweeps = slices.map((s) => (s.value / total) * 360);
  const segs = slices.map((s, i) => {
    const start = sweeps.slice(0, i).reduce((a, v) => a + v, 0);
    const end = start + sweeps[i];
    const mid = (start + end) / 2;
    const rOut = single ? R_MAX : R_MIN + (s.value / maxVal) * (R_MAX - R_MIN);
    return { ...s, color: palette[i % palette.length], pct: Math.round((s.value / total) * 100), start, end, mid, rOut };
  });
  const cur = active != null ? segs[active] : null;
  const top = segs[0];
  const second = segs[1] && segs[1].label !== "Other" ? segs[1] : null;
  const smallest = segs.length > 2 ? segs[segs.length - 1] : null;
  const topK = Math.min(2, segs.length);
  const topKpct = segs.slice(0, topK).reduce((a, s) => a + s.pct, 0);
  const avg = total / segs.length;

  return (
    <div>
      <div className="flex flex-col gap-lg lg:flex-row lg:items-center">
        {/* chart */}
        <div className="min-w-0 lg:flex-1" onMouseLeave={() => setActive(null)}>
          <svg viewBox={`0 0 ${W} ${H}`} className="h-auto w-full" role="img" aria-label={ariaLabel} preserveAspectRatio="xMidYMid meet">
            {segs.map((s, i) => {
              const a0 = single ? s.start : s.start + GAP_DEG / 2;
              const a1 = single ? s.end : s.end - GAP_DEG / 2;
              const [lx, ly] = polar((HUB + s.rOut) / 2, s.mid);
              const [tipX, tipY] = polar(s.rOut + 4, s.mid);
              const [kneeX, kneeY] = polar(s.rOut + 18, s.mid);
              const right = kneeX >= CX;
              const endX = right ? kneeX + STUB : kneeX - STUB;
              const anchor = right ? "start" : "end";
              const textX = right ? endX + 6 : endX - 6;
              const sel = active === i;
              const dimmed = active != null && !sel;
              const [ux, uy] = unit(s.mid);
              return (
                <g
                  key={s.label}
                  role="button"
                  tabIndex={0}
                  aria-pressed={sel}
                  aria-label={`${s.label}, ${s.pct} percent`}
                  onMouseEnter={() => setActive(i)}
                  onFocus={() => setActive(i)}
                  onBlur={() => setActive(null)}
                  className="cursor-pointer outline-none"
                  style={{
                    // CSS transform (not the SVG attr) so the lift + fade animate
                    // smoothly. The hub is drawn on top, so the lift reads as the
                    // slice pulling out, not a gap bug.
                    transform: sel ? `translate(${(ux * EXPLODE).toFixed(2)}px, ${(uy * EXPLODE).toFixed(2)}px)` : "translate(0px, 0px)",
                    opacity: dimmed ? 0.4 : 1,
                    transition: "transform 260ms cubic-bezier(0.22, 0.61, 0.36, 1), opacity 200ms ease",
                  }}
                >
                  <path d={sector(HUB, s.rOut, a0, a1)} fill="currentColor" className={s.color.text} stroke="currentColor" strokeWidth={sel ? 4 : 0} paintOrder="stroke" />
                  <text x={lx} y={ly} textAnchor="middle" dominantBaseline="central" className="fill-white" fontSize={s.pct >= 8 ? 22 : 14} fontWeight={700} pointerEvents="none">
                    {s.pct}%
                  </text>
                  <polyline points={`${tipX},${tipY} ${kneeX},${kneeY} ${endX},${kneeY}`} fill="none" stroke="currentColor" strokeWidth={1.5} className="text-subtle" />
                  <text x={textX} y={kneeY - 4} textAnchor={anchor} fill="currentColor" className={s.color.text} fontSize={15} fontWeight={700}>
                    {trim(s.label)}
                  </text>
                  <text x={textX} y={kneeY + 14} textAnchor={anchor} className="fill-muted" fontSize={13}>
                    {formatValue(s.value)}
                  </text>
                </g>
              );
            })}
            {/* Dark hub drawn 1px OVER the slice inner edge so there's no cream
                gap ("halo") and the slice-gap convergence at the centre is hidden. */}
            <circle cx={CX} cy={CY} r={HUB + 1} fill="currentColor" className="text-ink" pointerEvents="none" />
            <circle cx={CX} cy={CY} r={HUB - 28} fill="currentColor" className="text-canvas" pointerEvents="none" />
          </svg>
        </div>

        {/* whole-chart written summary + full ranked breakdown */}
        <aside className="lg:w-72 lg:shrink-0">
          <p className="text-label-md uppercase tracking-wide text-muted">About this chart</p>
          <p className="mt-sm text-body-md leading-relaxed text-ink">
            <strong className="tabular-nums">{formatValue(total)}</strong> across{" "}
            <strong>{segs.length}</strong> {segs.length === 1 ? itemNoun.replace(/s$/, "") : itemNoun} (avg{" "}
            <strong className="tabular-nums">{formatValue(Math.round(avg))}</strong> each).{" "}
            <em>
              <u>{top.label}</u>
            </em>{" "}
            leads with <strong>{top.pct}%</strong> (<strong className="tabular-nums">{formatValue(top.value)}</strong>)
            {second ? (
              <>
                , ahead of <em>{second.label}</em> at <strong>{second.pct}%</strong>
              </>
            ) : null}
            .{" "}
            {segs.length > 2 ? (
              <>
                The top <strong>{topK}</strong> make up <strong>{topKpct}%</strong> of {subject}
                {smallest ? (
                  <>
                    , while <em>{smallest.label}</em> trails at <strong>{smallest.pct}%</strong>
                  </>
                ) : null}
                .
              </>
            ) : null}
          </p>

          {/* full breakdown */}
          <ul className="mt-md divide-y divide-hairline border-t border-hairline">
            {segs.map((s, i) => (
              <li
                key={s.label}
                className="flex items-center justify-between gap-md py-xs"
                style={{ opacity: active != null && active !== i ? 0.5 : 1, transition: "opacity 200ms" }}
              >
                <span className="flex min-w-0 items-center gap-sm">
                  <span className={`size-2 shrink-0 rounded-full ${s.color.bg}`} aria-hidden="true" />
                  <span className="truncate text-body-sm text-ink">{s.label}</span>
                </span>
                <span className="shrink-0 text-body-sm tabular-nums text-muted">
                  {formatValue(s.value)} · <span className="text-ink">{s.pct}%</span>
                </span>
              </li>
            ))}
          </ul>
          <p className="mt-sm text-body-sm italic text-subtle">Hover a slice for its breakdown.</p>
        </aside>
      </div>

      {/* hovered-slice detail (slides in at the bottom) */}
      <div
        aria-live="polite"
        className={`overflow-hidden transition-all duration-300 ease-out ${
          cur ? "mt-md max-h-24 translate-y-0 opacity-100" : "max-h-0 -translate-y-1 opacity-0"
        }`}
      >
        {cur ? (
          <div className="flex items-center gap-sm rounded-lg bg-surface-tint px-md py-sm">
            <span className={`size-2.5 shrink-0 rounded-full ${cur.color.bg}`} aria-hidden="true" />
            <p className="text-body-sm text-ink">
              <span className="font-semibold">{cur.label}</span> — <strong className="tabular-nums">{formatValue(cur.value)}</strong>,{" "}
              <strong>{cur.pct}%</strong> of {subject}.
            </p>
          </div>
        ) : null}
      </div>

      <table className="sr-only">
        <caption>{ariaLabel}</caption>
        <thead>
          <tr>
            <th scope="col">Item</th>
            <th scope="col">Value</th>
            <th scope="col">Share</th>
          </tr>
        </thead>
        <tbody>
          {segs.map((s) => (
            <tr key={s.label}>
              <th scope="row">{s.label}</th>
              <td>{formatValue(s.value)}</td>
              <td>{s.pct}%</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
