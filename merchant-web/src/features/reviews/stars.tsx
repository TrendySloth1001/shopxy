import { Star, StarHalf } from "@/shared/icons";

/**
 * A 5-star rating display. Renders full / half / empty stars for `value`
 * (0..5). Decorative by default; pass an `aria-label` via `label` for the
 * accessible name when the stars are the only representation of the score.
 */
export function Stars({
  value,
  size = 16,
  label,
}: {
  value: number;
  size?: number;
  label?: string;
}) {
  const v = Math.max(0, Math.min(5, value));
  return (
    <span
      className="inline-flex items-center gap-px text-accent-amber"
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      {Array.from({ length: 5 }, (_, i) => {
        const filled = v >= i + 1;
        const half = !filled && v >= i + 0.5;
        if (half) {
          return (
            <span key={i} className="relative inline-flex">
              <Star size={size} className="text-hairline" />
              <StarHalf
                size={size}
                fill="currentColor"
                className="absolute inset-0"
              />
            </span>
          );
        }
        return (
          <Star
            key={i}
            size={size}
            fill={filled ? "currentColor" : "none"}
            className={filled ? "" : "text-hairline"}
          />
        );
      })}
    </span>
  );
}
