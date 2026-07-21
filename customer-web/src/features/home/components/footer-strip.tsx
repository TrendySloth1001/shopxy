import { FileCheck2, Headphones, Lock, ShieldCheck } from "@/shared/icons";

/**
 * "Why millions choose ShopXY" footer — port of `HomeFooterStrip`. A soft panel
 * with a 2×2 grid of trust cells, shown at the tail of the feed.
 */
const CELLS = [
  { icon: ShieldCheck, title: "100% Authentic", sub: "Sourced direct from brands" },
  { icon: Lock, title: "Secure payments", sub: "UPI · Cards · COD" },
  { icon: Headphones, title: "24×7 support", sub: "We're here when you need" },
  { icon: FileCheck2, title: "Easy returns", sub: "7-day no-questions" },
] as const;

export function FooterStrip() {
  return (
    <div className="mx-lg rounded-lg bg-hero-panel p-lg">
      <h2 className="text-center text-body-md font-extrabold text-ink">Why millions choose ShopXY</h2>
      <div className="mt-md grid grid-cols-2 gap-sm">
        {CELLS.map(({ icon: Icon, title, sub }) => (
          <div key={title} className="flex flex-col items-center gap-xs p-xs text-center">
            <Icon size={24} className="text-brand" aria-hidden />
            <span className="text-body-sm font-bold text-ink">{title}</span>
            <span className="text-micro text-muted">{sub}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
