"use client";

import Link from "next/link";
import { Zap } from "lucide-react";
import type { FlashDeal } from "@/features/home/types";
import { ImageBox } from "@/features/home/components/image-box";
import { CountdownChip } from "./countdown-chip";

function FlashTile({ deal }: { deal: FlashDeal }) {
  const claimedPct = Math.round(deal.soldPct * 100);
  return (
    <Link
      href={`/p/${deal.productId}`}
      className="group rounded-lg border border-hairline bg-white overflow-hidden transition-all duration-200 hover:shadow-floating hover:-translate-y-[2px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flash-accent flex flex-col"
    >
      {/* Image */}
      <span className="relative block aspect-square w-full overflow-hidden bg-canvas">
        <span className="block size-full transition-transform duration-300 group-hover:scale-[1.04]">
          <ImageBox url={deal.imageUrl} alt={deal.name} placeholderColor="#FFE3D2" />
        </span>
        {deal.discountPct > 0 ? (
          <span className="absolute left-[6px] top-[6px] bg-flash-accent text-white text-[11px] font-extrabold rounded-sm px-sm py-[2px]">
            -{deal.discountPct}%
          </span>
        ) : null}
      </span>

      {/* Info */}
      <span className="flex flex-1 flex-col p-sm">
        <span className="line-clamp-2 text-[12.5px] font-semibold leading-tight text-ink">
          {deal.name}
        </span>
        <span className="mt-xs flex items-baseline gap-[4px]">
          <span className="text-[15px] font-extrabold leading-none text-flash-accent">{deal.price}</span>
          {deal.originalPrice ? (
            <span className="text-[11px] text-muted line-through">{deal.originalPrice}</span>
          ) : null}
        </span>

        {/* Progress bar */}
        <span className="mt-sm block h-[5px] w-full overflow-hidden rounded-full bg-flash-from">
          <span
            className="block h-full rounded-full bg-flash-accent transition-[width]"
            style={{ width: `${claimedPct}%` }}
          />
        </span>
        <span className="mt-[3px] text-[10px] font-bold text-flash-accent">
          {claimedPct}% claimed
        </span>
      </span>
    </Link>
  );
}

/**
 * Full-page flash-deals grid — 2 columns on mobile, 3 on sm, 4 on lg.
 */
export function FlashDealsGrid({ deals }: { deals: FlashDeal[] }) {
  if (deals.length === 0) return null;
  const soonestMs = Math.min(...deals.map((d) => Date.parse(d.endAt)));

  return (
    <section className="rounded-lg bg-gradient-to-b from-flash-from to-flash-to p-lg">
      {/* Header */}
      <div className="mb-md flex items-center gap-sm">
        <Zap size={20} className="fill-flash-accent text-flash-accent" aria-hidden />
        <h2 className="text-[17px] font-extrabold text-ink">Flash Deals</h2>
        <span className="text-[13px] font-semibold text-flash-accent">— ending soon</span>
        <span className="ml-auto">
          <CountdownChip endAtMs={soonestMs} />
        </span>
      </div>

      {/* Grid */}
      <div className="grid grid-cols-2 gap-md sm:grid-cols-3 lg:grid-cols-4">
        {deals.map((d) => (
          <FlashTile key={d.saleId} deal={d} />
        ))}
      </div>
    </section>
  );
}
