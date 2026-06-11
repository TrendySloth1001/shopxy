import type { ReactNode } from "react";
import { ShieldCheck, Tag, Truck } from "lucide-react";

/**
 * Thin strip below the hero: headline discount pill + trust chips.
 * Mirrors the Flutter `_DealStrip` / `_TrustChip` widgets.
 */
export function BannerDealStrip({
  maxDiscountPct,
  productCount,
}: {
  maxDiscountPct: number;
  productCount: number;
}) {
  return (
    <div className="flex flex-wrap items-center gap-sm border-b border-hairline px-lg py-md">
      {/* Headline discount */}
      {maxDiscountPct > 0 ? (
        <span className="flex items-center gap-xs rounded-full bg-brand px-md py-[5px] text-[13px] font-extrabold text-white">
          <Tag size={14} aria-hidden />
          Up to {maxDiscountPct}% OFF
        </span>
      ) : productCount > 0 ? (
        <span className="text-[14px] font-extrabold text-ink">{productCount} curated picks</span>
      ) : null}

      {/* Trust chips */}
      <div className="ml-auto flex items-center gap-xs">
        <TrustChip icon={<Truck size={13} aria-hidden />} label="Free delivery" />
        <TrustChip icon={<ShieldCheck size={13} aria-hidden />} label="Genuine" />
      </div>
    </div>
  );
}

function TrustChip({ icon, label }: { icon: ReactNode; label: string }) {
  return (
    <span className="flex items-center gap-xs rounded-full border border-hairline bg-canvas px-sm py-[4px] text-[11px] font-semibold text-muted">
      {icon}
      {label}
    </span>
  );
}
