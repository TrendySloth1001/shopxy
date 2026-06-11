"use client";

import Link from "next/link";
import { Star } from "lucide-react";
import type { CatalogProduct } from "../types";
import { ImageBox } from "@/features/home/components/image-box";
import { resolveImageUrl } from "@/features/home/format";
import { formatINR } from "@/shared/format";

/**
 * Compact product card used on shop-profile and category-browse pages.
 * Fills its parent grid cell. Tap links to /p/[id].
 */
export function CatalogProductCard({ product }: { product: CatalogProduct }) {
  const p = product;
  const imageUrl = p.images.length > 0 ? resolveImageUrl(p.images[0].url) : "";
  const discounted = p.mrp > p.sellingPrice;
  const discountPct = discounted
    ? Math.round(Math.min(99, Math.max(0, (1 - p.sellingPrice / p.mrp) * 100)))
    : 0;

  return (
    <Link
      href={`/p/${p.id}`}
      className="group flex flex-col overflow-hidden rounded-md border border-hairline bg-white transition-shadow hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {/* Image */}
      <span className="relative block aspect-square w-full overflow-hidden rounded-t-md bg-hero-panel">
        {imageUrl ? (
          <ImageBox url={imageUrl} alt={p.name} />
        ) : null}
        {discountPct > 0 ? (
          <span className="absolute left-[6px] top-[6px] rounded-xs bg-gradient-to-br from-brand to-brand-strong px-[6px] py-[2px] text-[10px] font-extrabold tracking-[0.4px] text-white shadow-floating">
            {discountPct}% OFF
          </span>
        ) : null}
      </span>

      {/* Info */}
      <span className="flex flex-1 flex-col gap-xs p-sm">
        <span className="line-clamp-2 text-[12.5px] font-semibold leading-tight text-ink">
          {p.name}
        </span>

        <span className="mt-auto flex flex-col gap-[2px]">
          <span className="flex items-baseline gap-[4px]">
            <span className="text-[15px] font-extrabold leading-none text-ink">
              {formatINR(p.sellingPrice)}
            </span>
            {discounted ? (
              <span className="text-[11px] text-muted line-through">
                {formatINR(p.mrp)}
              </span>
            ) : null}
          </span>

          {p.ratingAvg != null && p.ratingCount > 0 ? (
            <span className="flex items-center gap-[3px]">
              <Star size={11} className="fill-success text-success" aria-hidden />
              <span className="text-[11px] font-semibold text-muted">
                {p.ratingAvg.toFixed(1)} ({p.ratingCount})
              </span>
            </span>
          ) : null}
        </span>
      </span>
    </Link>
  );
}
