/**
 * Lightweight, dependency-free SVG charts that fit the token palette. The
 * stroke uses `currentColor` (set a `text-*` class on the element) and a
 * non-scaling stroke so the line stays crisp while the SVG stretches to fill
 * its container. Heights come from a Tailwind class, not inline pixels.
 */

/**
 * A filled line chart. `values` are plotted left→right and scaled to the tallest
 * point in either series. `overlay` (e.g. a moving average) is drawn as a muted
 * dashed line behind the primary line.
 */
export function LineChart({
  values,
  overlay,
  heightClass = "h-32",
  ariaLabel,
}: {
  values: number[];
  overlay?: number[];
  heightClass?: string;
  ariaLabel?: string;
}) {
  if (values.length === 0) return null;
  const W = 100;
  const H = 100;
  const max = Math.max(...values, ...(overlay ?? []), 1);

  const toPts = (vals: number[]): string => {
    if (vals.length === 1) {
      const y = H - (vals[0] / max) * H;
      return `0,${y} ${W},${y}`;
    }
    return vals.map((v, i) => `${(i / (vals.length - 1)) * W},${H - (v / max) * H}`).join(" ");
  };

  const linePts = toPts(values);
  const areaPts = `0,${H} ${linePts} ${W},${H}`;

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      preserveAspectRatio="none"
      role="img"
      aria-label={ariaLabel}
      className={`w-full text-brand ${heightClass}`}
    >
      <polygon points={areaPts} fill="currentColor" fillOpacity={0.1} stroke="none" />
      {overlay && overlay.length > 0 ? (
        <polyline
          points={toPts(overlay)}
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
  );
}
