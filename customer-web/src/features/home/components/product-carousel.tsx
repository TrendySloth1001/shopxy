"use client";

import { useRef } from "react";
import { ChevronLeft, ChevronRight } from "@/shared/icons";
import type { ProductCard } from "../types";
import { ProductTile } from "./product-tile";
import { SectionHeader } from "./section-header";

export function searchHref(query: string): string {
  return `/search?q=${encodeURIComponent(query)}`;
}

export function ProductCarousel({
  eyebrow,
  title,
  products,
  source = "home",
  layout = "grid",
}: {
  eyebrow?: string;
  title: string;
  products: ProductCard[];
  source?: string;
  layout?: "grid" | "rail";
}) {
  const scrollRef = useRef<HTMLDivElement>(null);

  function scroll(dir: "left" | "right") {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollBy({ left: dir === "right" ? el.clientWidth * 0.8 : -el.clientWidth * 0.8, behavior: "smooth" });
  }

  if (products.length === 0) return null;

  if (layout === "grid") {
    return (
      <section>
        <SectionHeader eyebrow={eyebrow} title={title} seeAllHref={searchHref(title)} variant="circle" />
        <div className="mt-md grid grid-cols-2 gap-md px-lg md:grid-cols-3 lg:grid-cols-4">
          {products.map((p) => (
            <ProductTile key={p.productId} product={p} source={source} />
          ))}
        </div>
      </section>
    );
  }

  return (
    <section className="group/rail">
      <SectionHeader eyebrow={eyebrow} title={title} seeAllHref={searchHref(title)} variant="circle" />
      <div className="relative mt-md">
        <button
          type="button"
          onClick={() => scroll("left")}
          aria-label="Scroll left"
          className="absolute left-0 top-1/2 z-10 -translate-y-1/2 flex size-8 items-center justify-center rounded-full border border-hairline bg-white shadow-menu opacity-0 transition-opacity duration-200 group-hover/rail:opacity-100 focus-visible:opacity-100 focus-visible:outline-none hover:bg-canvas touch:hidden pointer-coarse:hidden"
        >
          <ChevronLeft size={18} className="text-ink" aria-hidden />
        </button>

        <div
          ref={scrollRef}
          className="flex gap-lg overflow-x-auto scroll-smooth px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        >
          {products.map((p) => (
            <div key={p.productId} className="w-[158px] shrink-0">
              <ProductTile product={p} source={source} />
            </div>
          ))}
        </div>

        <button
          type="button"
          onClick={() => scroll("right")}
          aria-label="Scroll right"
          className="absolute right-0 top-1/2 z-10 -translate-y-1/2 flex size-8 items-center justify-center rounded-full border border-hairline bg-white shadow-menu opacity-0 transition-opacity duration-200 group-hover/rail:opacity-100 focus-visible:opacity-100 focus-visible:outline-none hover:bg-canvas touch:hidden pointer-coarse:hidden"
        >
          <ChevronRight size={18} className="text-ink" aria-hidden />
        </button>
      </div>
    </section>
  );
}
