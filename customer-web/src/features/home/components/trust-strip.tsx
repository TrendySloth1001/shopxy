import { BadgeCheck, RotateCcw, ShieldCheck, Tag } from "lucide-react";

/**
 * Trust promises — port of `HomeTrustStrip`. A compact, evenly-spaced row of
 * icon + label badges. Icons sit inside brand-soft circular chips for a
 * premium Indian-marketplace feel.
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
        <span key={label} className="flex flex-1 flex-col items-center gap-[5px] sm:flex-row sm:justify-center sm:gap-[6px]">
          {/* Brand-soft circular chip around the icon */}
          <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-brand-soft">
            <Icon size={15} className="text-brand-strong" aria-hidden />
          </span>
          <span className="line-clamp-1 text-center text-[10px] font-semibold text-muted sm:text-[12px] sm:text-ink">
            {label}
          </span>
        </span>
      ))}
    </div>
  );
}
