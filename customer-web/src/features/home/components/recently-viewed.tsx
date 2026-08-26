"use client";

import { useRef } from "react";
import Link from "next/link";
import { ChevronLeft, ChevronRight } from "@/shared/icons";
import type { ProductCard } from "../types";
import { ImageBox } from "./image-box";
import { productHref } from "./product-tile";

export function RecentlyViewed({ items }: { items: ProductCard[] }) {
  const scrollRef = useRef<HTMLDivElement>(null);

  function scroll(dir: "left" | "right") {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollBy({ left: dir === "right" ? el.clientWidth * 0.8 : -el.clientWidth * 0.8, behavior: "smooth" });
  }

  if (items.length === 0) return null;
  return (
    <section className="group/rail">
      <div className="flex items-center justify-between px-lg">
        <h2 className="text-title-md font-extrabold text-ink">Pick up where you left off</h2>
      </div>
      <div className="relative mt-md">
        <button
          type="button"
          onClick={() => scroll("left")}
          aria-label="Scroll left"
          className="absolute left-0 top-1/2 z-10 -translate-y-1/2 flex size-8 items-center justify-center rounded-full border border-hairline bg-white shadow-menu opacity-0 transition-opacity duration-200 group-hover/rail:opacity-100 focus-visible:opacity-100 focus-visible:outline-none hover:bg-canvas pointer-coarse:hidden"
        >
          <ChevronLeft size={18} className="text-ink" aria-hidden />
        </button>

        <div
          ref={scrollRef}
          className="flex gap-md overflow-x-auto scroll-smooth px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          {items.map((p) => (
            <Link
              key={p.productId}
              href={productHref(p.productId)}
              className="flex w-[220px] shrink-0 items-center gap-sm rounded-lg border border-hairline bg-white p-sm transition-all duration-200 hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <span className="relative block size-[84px] shrink-0 overflow-hidden rounded-md">
                {p.imageUrl ? (
                  <ImageBox url={p.imageUrl} alt={p.name} placeholderColor={p.bgColor} />
                ) : (
                  <span className="flex size-full items-center justify-center rounded-md bg-brand-soft">
                    <span className="text-[22px] font-extrabold leading-none text-brand">
                      {(p.name[0] ?? "?").toUpperCase()}
                    </span>
                  </span>
                )}
              </span>
              <span className="flex min-w-0 flex-1 flex-col">
                <span className="line-clamp-2 text-body-sm leading-tight text-ink">{p.name}</span>
                <span className="mt-xs text-body-md font-extrabold text-ink">{p.price}</span>
                {p.originalPrice ? (
                  <span className="text-micro text-muted line-through">{p.originalPrice}</span>
                ) : null}
              </span>
            </Link>
          ))}
        </div>

        <button
          type="button"
          onClick={() => scroll("right")}
          aria-label="Scroll right"
          className="absolute right-0 top-1/2 z-10 -translate-y-1/2 flex size-8 items-center justify-center rounded-full border border-hairline bg-white shadow-menu opacity-0 transition-opacity duration-200 group-hover/rail:opacity-100 focus-visible:opacity-100 focus-visible:outline-none hover:bg-canvas pointer-coarse:hidden"
        >
          <ChevronRight size={18} className="text-ink" aria-hidden />
        </button>
      </div>
    </section>
  );
}
