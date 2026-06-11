"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { ChevronLeft, ChevronRight, Zap } from "lucide-react";
import type { FlashDeal } from "../types";
import { recordTap } from "../tracking";
import { productHref } from "./product-tile";
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
 * Desktop shows left/right scroll arrows on hover of the rail.
 * Countdown chip uses the shared spec: bg-ink text-white tabular-nums.
 */
export function FlashDeals({ deals }: { deals: FlashDeal[] }) {
  const [now, setNow] = useState(() => Date.now());
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  function scroll(dir: "left" | "right") {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollBy({ left: dir === "right" ? el.clientWidth * 0.8 : -el.clientWidth * 0.8, behavior: "smooth" });
  }

  if (deals.length === 0) return null;
  const soonest = Math.min(...deals.map((d) => Date.parse(d.endAt)));

  return (
    <section className="group/rail bg-gradient-to-b from-flash-from to-flash-to py-lg">
      <div className="flex items-center gap-sm px-lg">
        <Zap size={22} className="fill-flash-accent text-flash-accent" aria-hidden />
        <h2 className="text-[18px] font-extrabold text-ink">Flash Deals</h2>
        {/* Countdown chip — bg-ink text-white per spec */}
        <span className="rounded-sm bg-ink px-sm py-[2px] text-[11px] font-bold tabular-nums text-timer-text">
          Ends in {countdown(soonest, now)}
        </span>
        <Link
          href="/deals"
          className="ml-auto flex items-center gap-[2px] text-[12px] font-bold text-flash-accent focus-visible:outline-none focus-visible:underline"
        >
          See all <ChevronRight size={14} aria-hidden />
        </Link>
      </div>

      <div className="relative mt-md">
        {/* Left arrow */}
        <button
          type="button"
          onClick={() => scroll("left")}
          aria-label="Scroll deals left"
          className="absolute left-0 top-1/2 z-10 -translate-y-1/2 flex size-8 items-center justify-center rounded-full border border-hairline bg-white shadow-menu opacity-0 transition-opacity duration-200 group-hover/rail:opacity-100 focus-visible:opacity-100 focus-visible:outline-none pointer-coarse:hidden"
        >
          <ChevronLeft size={18} className="text-ink" aria-hidden />
        </button>

        <div
          ref={scrollRef}
          className="flex gap-md overflow-x-auto scroll-smooth px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          {deals.map((d) => (
            <Link
              key={d.saleId}
              href={productHref(d.productId)}
              onClick={() => recordTap(d.productId, "flash")}
              className="group flex w-[150px] shrink-0 flex-col overflow-hidden rounded-lg border border-hairline bg-white transition-all duration-200 hover:-translate-y-[2px] hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-flash-accent"
            >
              <span className="relative block aspect-square w-full overflow-hidden bg-canvas">
                {d.imageUrl ? (
                  <span className="block size-full transition-transform duration-300 group-hover:scale-[1.04]">
                    <ImageBox url={d.imageUrl} alt={d.name} placeholderColor="#FFE3D2" />
                  </span>
                ) : (
                  <span className="flex size-full items-center justify-center bg-brand-soft">
                    <span className="text-[24px] font-extrabold leading-none text-brand">
                      {(d.name[0] ?? "?").toUpperCase()}
                    </span>
                  </span>
                )}
                {d.discountPct > 0 ? (
                  <span className="absolute left-[4px] top-[4px] rounded-sm bg-flash-accent px-[6px] py-[2px] text-[11px] font-extrabold text-white">
                    -{d.discountPct}%
                  </span>
                ) : null}
              </span>
              <span className="flex flex-col p-sm">
                <span className="line-clamp-2 text-[12px] leading-tight text-ink">{d.name}</span>
                <span className="mt-[2px] flex items-baseline gap-[4px]">
                  <span className="text-[14px] font-extrabold text-flash-accent">{d.price}</span>
                  {d.originalPrice ? (
                    <span className="text-[10px] text-muted line-through">{d.originalPrice}</span>
                  ) : null}
                </span>
                {/* Stock progress bar — only if soldPct data is present */}
                {d.soldPct > 0 ? (
                  <>
                    <span className="mt-xs h-[4px] w-full overflow-hidden rounded-full bg-flash-from">
                      <span
                        className="block h-full rounded-full bg-flash-accent transition-[width] duration-500"
                        style={{ width: `${Math.min(100, Math.round(d.soldPct * 100))}%` }}
                      />
                    </span>
                    <span className="mt-[2px] text-[10px] font-bold text-flash-accent">
                      {Math.round(d.soldPct * 100)}% claimed
                    </span>
                  </>
                ) : null}
              </span>
            </Link>
          ))}
        </div>

        {/* Right arrow */}
        <button
          type="button"
          onClick={() => scroll("right")}
          aria-label="Scroll deals right"
          className="absolute right-0 top-1/2 z-10 -translate-y-1/2 flex size-8 items-center justify-center rounded-full border border-hairline bg-white shadow-menu opacity-0 transition-opacity duration-200 group-hover/rail:opacity-100 focus-visible:opacity-100 focus-visible:outline-none pointer-coarse:hidden"
        >
          <ChevronRight size={18} className="text-ink" aria-hidden />
        </button>
      </div>
    </section>
  );
}
