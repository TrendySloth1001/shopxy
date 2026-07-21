"use client";

import { StarSolidIcon } from "@/shared/icons";
import Link from "next/link";
import type { CatalogProduct } from "../types";
import { ImageBox } from "@/features/home/components/image-box";
import { mediaSrc } from "@/shared/media";
import { formatINR } from "@/shared/format";

/**
 * Compact product card used on shop-profile and category-browse pages.
 * Fills its parent grid cell. Tap links to /p/[id].
 *
 * Visual spec: white card, hairline border, rounded-lg, hover lift 2px + shadow-floating,
 * discount badge top-left brand green, rating chip success-green pill, bold price + line-through MRP.
 */
export function CatalogProductCard({ product }: { product: CatalogProduct }) {
  const p = product;
  const imageUrl = p.images.length > 0 ? (mediaSrc(p.images[0].url) ?? "") : "";
  const discounted = p.mrp > p.sellingPrice;
  const discountPct = discounted
    ? Math.round(Math.min(99, Math.max(0, (1 - p.sellingPrice / p.mrp) * 100)))
    : 0;

  return (
    <Link
      href={`/p/${p.id}`}
      className="group rounded-lg border border-hairline bg-white overflow-hidden transition-all duration-200 hover:shadow-floating hover:-translate-y-[2px] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft flex flex-col"
    >
      {/* Image */}
      <span className="relative block aspect-square w-full overflow-hidden bg-canvas">
        {imageUrl ? (
          <span className="block size-full transition-transform duration-300 group-hover:scale-[1.04]">
            <ImageBox url={imageUrl} alt={p.name} fit="cover" />
          </span>
        ) : (
          <ProductImageFallback name={p.name} />
        )}
        {discountPct > 0 ? (
          <span className="absolute left-[6px] top-[6px] bg-brand text-white text-[11px] font-extrabold rounded-sm px-sm py-[2px]">
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
          {p.ratingAvg != null && p.ratingCount > 0 ? (
            <span className="mb-[2px] inline-flex items-center gap-[3px]">
              <span className="inline-flex items-center gap-[3px] rounded-sm bg-success px-[6px] py-[2px] text-[11px] font-bold text-white">
                {p.ratingAvg.toFixed(1)}
                <StarSolidIcon size={9} className="shrink-0" />
              </span>
              <span className="text-[10px] text-muted">
                ({p.ratingCount > 999 ? `${(p.ratingCount / 1000).toFixed(1)}k` : p.ratingCount})
              </span>
            </span>
          ) : null}

          <span className="flex items-baseline gap-[4px]">
            <span className="text-[15px] font-extrabold leading-none text-ink">
              {formatINR(p.sellingPrice)}
            </span>
            {discounted ? (
              <span className="text-[11px] text-muted line-through">
                {formatINR(p.mrp)}
              </span>
            ) : null}
            {discountPct > 0 ? (
              <span className="text-[11px] font-bold text-brand">
                {discountPct}% off
              </span>
            ) : null}
          </span>
        </span>
      </span>
    </Link>
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Brand-soft tinted placeholder for products with no image — first letter of name. */
function ProductImageFallback({ name }: { name: string }) {
  const initial = name.trim()[0]?.toUpperCase() ?? "?";
  return (
    <span className="flex size-full items-center justify-center bg-brand-soft">
      <span className="text-[40px] font-extrabold text-brand opacity-30 select-none">{initial}</span>
    </span>
  );
}
