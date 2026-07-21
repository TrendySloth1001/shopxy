"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";

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

// Geometry (SVG user units). Wide viewBox so the two callout columns get real
// horizontal room on either side of the pie (that's what stops label overlap).
const W = 900;
const H = 520;
const CX = W / 2;
const CY = H / 2;
const HUB = 86;
const R_MIN = 184;
const R_MAX = 228;
const GAP_DEG = 3;
const EXPLODE = 14; // how far the hovered slice lifts out (smoothly, via CSS transform)

// Callout layout. Labels are stacked along a fixed outer column per side with a
// minimum vertical gap; the leader line stretches horizontally out to it.
const COL_R = R_MAX + 26; // radius of the label column (just past the widest slice)
const TAIL = 22; // length of the final horizontal run into the text
const LABEL_GAP = 34; // min vertical spacing between two stacked callouts
const LABEL_TOP = 22; // top bound of a callout column
const LABEL_BOT = H - 14; // bottom bound of a callout column

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
function collapse(rows: PieRow[], maxSlices: number, otherLabel: string): PieRow[] {
  const sorted = rows.filter((r) => r.value > 0).sort((a, b) => b.value - a.value);
  if (sorted.length <= maxSlices) return sorted;
  const head = sorted.slice(0, maxSlices - 1);
  head.push({ label: otherLabel, value: sorted.slice(maxSlices - 1).reduce((s, r) => s + r.value, 0) });
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
  const t = useTranslations("dashboard");
  const otherLabel = t("pie.other");
  const [active, setActive] = useState<number | null>(null);

  const slices = collapse(rows, palette.length, otherLabel);
  const total = slices.reduce((s, r) => s + r.value, 0);
  if (total <= 0) return <p className="text-body-sm text-muted">{t("pie.noData")}</p>;

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
  // De-collide the callouts: for each slice compute its leader-line tip/knee,
  // pick a side, then stack the labels along that side's column, pushing any
  // that land too close apart (and back inside the frame). Indexed by slice.
  const layout = segs.map((s, i) => {
    const ang = single ? 0 : s.mid;
    const [tipX, tipY] = polar(s.rOut + 4, ang);
    const [kneeX, kneeY] = polar(s.rOut + 18, ang);
    const right = single ? true : kneeX >= CX;
    return { i, tipX, tipY, kneeX, kneeY, right, y: kneeY };
  });
  for (const side of [true, false]) {
    const col = layout.filter((l) => l.right === side).sort((a, b) => a.kneeY - b.kneeY);
    for (let k = 1; k < col.length; k++) {
      if (col[k].y - col[k - 1].y < LABEL_GAP) col[k].y = col[k - 1].y + LABEL_GAP;
    }
    const overflow = col.length ? col[col.length - 1].y - LABEL_BOT : 0;
    if (overflow > 0) for (const l of col) l.y -= overflow;
    for (let k = 0; k < col.length; k++) {
      const minY = k === 0 ? LABEL_TOP : col[k - 1].y + LABEL_GAP;
      if (col[k].y < minY) col[k].y = minY;
    }
  }

  const cur = active != null ? segs[active] : null;
  const top = segs[0];
  const second = segs[1] && segs[1].label !== otherLabel ? segs[1] : null;
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
              // A lone 100% slice renders as a full ring; put its % at the top.
              const [lx, ly] = polar((HUB + s.rOut) / 2, single ? 0 : s.mid);
              const L = layout[i];
              const right = L.right;
              const labelY = L.y;
              const colX = right ? CX + COL_R : CX - COL_R;
              const bendX = right ? colX - TAIL : colX + TAIL;
              const anchor = right ? "start" : "end";
              const textX = right ? colX + 6 : colX - 6;
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
                    // A lone full ring has nothing to lift away from, so skip the explode.
                    transform: sel && !single ? `translate(${(ux * EXPLODE).toFixed(2)}px, ${(uy * EXPLODE).toFixed(2)}px)` : "translate(0px, 0px)",
                    opacity: dimmed ? 0.4 : 1,
                    transition: "transform 260ms cubic-bezier(0.22, 0.61, 0.36, 1), opacity 200ms ease",
                  }}
                >
                  {single ? (
                    <circle
                      cx={CX}
                      cy={CY}
                      r={(HUB + s.rOut) / 2}
                      fill="none"
                      stroke="currentColor"
                      strokeWidth={s.rOut - HUB}
                      className={s.color.text}
                    />
                  ) : (
                    <path d={sector(HUB, s.rOut, a0, a1)} fill="currentColor" className={s.color.text} stroke="currentColor" strokeWidth={sel ? 4 : 0} paintOrder="stroke" />
                  )}
                  <text x={lx} y={ly} textAnchor="middle" dominantBaseline="central" className="fill-white" fontSize={s.pct >= 8 ? 22 : 14} fontWeight={700} pointerEvents="none">
                    {s.pct}%
                  </text>
                  <polyline
                    points={`${L.tipX},${L.tipY} ${L.kneeX},${L.kneeY} ${bendX},${labelY} ${colX},${labelY}`}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    className="text-subtle"
                  />
                  <text x={textX} y={labelY - 4} textAnchor={anchor} fill="currentColor" className={s.color.text} fontSize={15} fontWeight={700}>
                    {trim(s.label)}
                  </text>
                  <text x={textX} y={labelY + 13} textAnchor={anchor} className="fill-muted" fontSize={13}>
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
        <aside className="lg:w-64 lg:shrink-0">
          <p className="text-label-md uppercase tracking-wide text-muted">{t("pie.about")}</p>
          <p className="mt-sm text-body-md leading-relaxed text-ink">
            {t.rich("pie.summaryTotal", {
              total: formatValue(total),
              count: segs.length,
              noun: itemNoun,
              avg: formatValue(Math.round(avg)),
              b: (chunks) => <strong>{chunks}</strong>,
              num: (chunks) => <strong className="tabular-nums">{chunks}</strong>,
            })}{" "}
            {t.rich("pie.summaryLeader", {
              label: top.label,
              pct: top.pct,
              value: formatValue(top.value),
              b: (chunks) => <strong>{chunks}</strong>,
              num: (chunks) => <strong className="tabular-nums">{chunks}</strong>,
              em: (chunks) => (
                <em>
                  <u>{chunks}</u>
                </em>
              ),
            })}
            {second
              ? t.rich("pie.summarySecond", {
                  label: second.label,
                  pct: second.pct,
                  b: (chunks) => <strong>{chunks}</strong>,
                  em: (chunks) => <em>{chunks}</em>,
                })
              : null}
            {". "}
            {segs.length > 2
              ? t.rich("pie.summaryTopK", {
                  topK,
                  topKpct,
                  subject,
                  b: (chunks) => <strong>{chunks}</strong>,
                })
              : null}
            {segs.length > 2 && smallest
              ? t.rich("pie.summarySmallest", {
                  label: smallest.label,
                  pct: smallest.pct,
                  b: (chunks) => <strong>{chunks}</strong>,
                  em: (chunks) => <em>{chunks}</em>,
                })
              : null}
            {segs.length > 2 ? "." : null}
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
          <p className="mt-sm text-body-sm italic text-subtle">{t("pie.hoverHint")}</p>
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
              {t.rich("pie.sliceDetail", {
                label: cur.label,
                value: formatValue(cur.value),
                pct: cur.pct,
                subject,
                name: (chunks) => <span className="font-semibold">{chunks}</span>,
                b: (chunks) => <strong>{chunks}</strong>,
                num: (chunks) => <strong className="tabular-nums">{chunks}</strong>,
              })}
            </p>
          </div>
        ) : null}
      </div>

      <table className="sr-only">
        <caption>{ariaLabel}</caption>
        <thead>
          <tr>
            <th scope="col">{t("pie.tableItem")}</th>
            <th scope="col">{t("pie.tableValue")}</th>
            <th scope="col">{t("pie.tableShare")}</th>
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
