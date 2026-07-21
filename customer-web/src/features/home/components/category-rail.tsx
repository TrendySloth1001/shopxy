"use client";

import { useRef } from "react";
import Link from "next/link";
import { ChevronLeft, ChevronRight } from "@/shared/icons";
import type { CategoryPuck } from "../types";
import { ImageBox } from "./image-box";

/** Category destination — canonical category products route. */
function categoryHref(p: CategoryPuck): string {
  return p.slug ? `/c/${p.slug}` : "/categories";
}

/**
 * Category chips — a horizontally scrolling rail of pill chips, each with a
 * small round thumbnail and the full category label inline (chips size to
 * content, so long names aren't truncated). Falls back to the tint + first
 * letter when a category has no image. Desktop shows left/right scroll arrows
 * on hover.
 */
export function CategoryRail({ pucks }: { pucks: CategoryPuck[] }) {
  const scrollRef = useRef<HTMLDivElement>(null);

  function scroll(dir: "left" | "right") {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollBy({ left: dir === "right" ? el.clientWidth * 0.7 : -el.clientWidth * 0.7, behavior: "smooth" });
  }

  if (pucks.length === 0) return null;
  return (
    <nav aria-label="Categories" className="group/rail relative bg-white">
      {/* Left arrow */}
      <button
        type="button"
        onClick={() => scroll("left")}
        aria-label="Scroll categories left"
        className="absolute left-0 top-1/2 z-10 -translate-y-1/2 flex size-8 items-center justify-center rounded-full border border-hairline bg-white shadow-menu opacity-0 transition-opacity duration-200 group-hover/rail:opacity-100 focus-visible:opacity-100 focus-visible:outline-none pointer-coarse:hidden"
      >
        <ChevronLeft size={18} className="text-ink" aria-hidden />
      </button>

      <div
        ref={scrollRef}
        className="flex gap-sm overflow-x-auto scroll-smooth px-lg py-md [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {pucks.map((p) => (
          <Link
            key={p.categoryId}
            href={categoryHref(p)}
            className="group flex shrink-0 items-center gap-sm rounded-full border border-hairline bg-white py-[5px] pl-[5px] pr-md transition-all duration-200 hover:border-brand hover:bg-brand-soft hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            <span
              className="flex size-7 shrink-0 items-center justify-center overflow-hidden rounded-full"
              style={{ backgroundColor: p.tint }}
            >
              {p.imageUrl ? (
                <ImageBox url={p.imageUrl} alt={p.label} placeholderColor={p.tint} />
              ) : (
                <span className="text-body-sm font-extrabold text-ink">{(p.label[0] ?? "?").toUpperCase()}</span>
              )}
            </span>
            <span className="whitespace-nowrap text-body-sm font-semibold text-ink group-hover:text-brand-strong">
              {p.label}
            </span>
          </Link>
        ))}
      </div>

      {/* Right arrow */}
      <button
        type="button"
        onClick={() => scroll("right")}
        aria-label="Scroll categories right"
        className="absolute right-0 top-1/2 z-10 -translate-y-1/2 flex size-8 items-center justify-center rounded-full border border-hairline bg-white shadow-menu opacity-0 transition-opacity duration-200 group-hover/rail:opacity-100 focus-visible:opacity-100 focus-visible:outline-none pointer-coarse:hidden"
      >
        <ChevronRight size={18} className="text-ink" aria-hidden />
      </button>
    </nav>
  );
}
