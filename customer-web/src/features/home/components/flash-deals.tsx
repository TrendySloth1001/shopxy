"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ChevronRight, Zap } from "lucide-react";
import type { FlashDeal } from "../types";
import { recordTap } from "../tracking";
import { productHref } from "./product-tile";
import { searchHref } from "./product-carousel";
import { ImageBox } from "./image-box";

/** "HH:MM:SS" remaining until `endAtMs`; clamps to 00:00:00 once elapsed. */
function countdown(endAtMs: number, nowMs: number): string {
  let s = Math.max(0, Math.floor((endAtMs - nowMs) / 1000));
  const h = Math.floor(s / 3600);
  s -= h * 3600;
  const m = Math.floor(s / 60);
  s -= m * 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

/**
 * Flash-deals strip — port of `HomeFlashDeals`. Peach→salmon gradient panel
 * with a bolt header, a live nearest-expiry countdown, and horizontally
 * scrolling deal cards (discount badge, price, sold-progress bar).
 */
export function FlashDeals({ deals }: { deals: FlashDeal[] }) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  if (deals.length === 0) return null;
  const soonest = Math.min(...deals.map((d) => Date.parse(d.endAt)));

  return (
    <section className="bg-gradient-to-b from-flash-from to-flash-to py-lg">
      <div className="flex items-center gap-sm px-lg">
        <Zap size={22} className="fill-flash-accent text-flash-accent" aria-hidden />
        <h2 className="text-[18px] font-extrabold text-ink">Flash Deals</h2>
        <span className="rounded-xs bg-ink px-sm py-[2px] text-[11px] font-bold tabular-nums text-timer-text">
          Ends in {countdown(soonest, now)}
        </span>
        <Link
          href={searchHref("flash deals")}
          className="ml-auto flex items-center gap-[2px] text-[12px] font-bold text-flash-accent focus-visible:outline-none focus-visible:underline"
        >
          See all <ChevronRight size={14} aria-hidden />
        </Link>
      </div>

      <div className="mt-md flex gap-md overflow-x-auto px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {deals.map((d) => (
          <Link
            key={d.saleId}
            href={productHref(d.productId)}
            onClick={() => recordTap(d.productId, "flash")}
            className="flex w-[150px] shrink-0 flex-col rounded-md bg-white p-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flash-accent"
          >
            <span className="relative block aspect-square w-full overflow-hidden rounded-sm">
              <ImageBox url={d.imageUrl} alt={d.name} placeholderColor="#FFE3D2" />
              {d.discountPct > 0 ? (
                <span className="absolute left-[4px] top-[4px] rounded-xs bg-flash-accent px-[6px] py-[2px] text-[11px] font-extrabold text-white">
                  -{d.discountPct}%
                </span>
              ) : null}
            </span>
            <span className="mt-xs line-clamp-2 text-[12px] leading-tight text-ink">{d.name}</span>
            <span className="mt-[2px] flex items-baseline gap-[4px]">
              <span className="text-[14px] font-extrabold text-flash-accent">{d.price}</span>
              {d.originalPrice ? (
                <span className="text-[10px] text-muted line-through">{d.originalPrice}</span>
              ) : null}
            </span>
            <span className="mt-xs h-[5px] w-full overflow-hidden rounded-sm bg-flash-from">
              <span
                className="block h-full rounded-sm bg-flash-accent"
                style={{ width: `${Math.round(d.soldPct * 100)}%` }}
              />
            </span>
            <span className="mt-[2px] text-[10px] font-bold text-flash-accent">
              {Math.round(d.soldPct * 100)}% claimed
            </span>
          </Link>
        ))}
      </div>
    </section>
  );
}
