import { BadgeCheck, RotateCcw, ShieldCheck, Tag } from "lucide-react";

/**
 * Trust promises — port of `HomeTrustStrip`. A compact, evenly-spaced row of
 * icon + label badges (the web shows the static layout; the mobile app rotates
 * them in a carousel, which collapses to this same row under reduce-motion).
 */
const ITEMS = [
  { icon: Tag, label: "Free delivery" },
  { icon: RotateCcw, label: "7-day returns" },
  { icon: ShieldCheck, label: "100% authentic" },
  { icon: BadgeCheck, label: "Best prices" },
] as const;

export function TrustStrip() {
  return (
    <div className="flex items-center justify-between gap-sm px-lg">
      {ITEMS.map(({ icon: Icon, label }) => (
        <span key={label} className="flex flex-1 items-center justify-center gap-[6px]">
          <Icon size={16} className="text-brand-strong" aria-hidden />
          <span className="line-clamp-1 text-center text-[10.5px] font-semibold text-muted sm:text-[12.5px] sm:text-ink">
            {label}
          </span>
        </span>
      ))}
    </div>
  );
}
