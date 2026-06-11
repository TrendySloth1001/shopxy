import Link from "next/link";
import { Star } from "lucide-react";
import type { BannerProduct } from "../types";
import { ImageBox } from "@/features/home/components/image-box";
import { formatINR } from "@/shared/format";

/**
 * Product card for the banner detail product grid.
 *
 * Shows the sale price (banner-specific flash price) vs the crossed-out
 * selling price, a "You save …" line, a discount chip, and the rating pill.
 * Tapping routes to the canonical PDP. Mirrors the Flutter `_ProductCard` in
 * `banner_slide_detail_page.dart`.
 *
 * Note: sale price is display-only — the cart charges the regular sellingPrice.
 */
export function BannerProductCard({ product }: { product: BannerProduct }) {
  const p = product;
  const hasDiscount = p.discountPct > 0;
  const priceShown = hasDiscount ? p.salePrice : p.sellingPrice;
  const priceCrossed = hasDiscount ? p.sellingPrice : p.mrp > p.sellingPrice ? p.mrp : 0;
  const saves = priceCrossed > 0 ? priceCrossed - priceShown : 0;

  return (
    <Link
      href={`/p/${p.id}`}
      className="group flex flex-col overflow-hidden rounded-md bg-white shadow-floating transition-shadow hover:shadow-menu focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {/* Image */}
      <span className="relative block aspect-square w-full overflow-hidden">
        <ImageBox url={p.imageUrl} alt={p.name} />
        {hasDiscount ? (
          <span className="absolute left-[6px] top-[6px] rounded-xs bg-gradient-to-br from-brand to-brand-strong px-[6px] py-[2px] text-[10px] font-extrabold tracking-[0.4px] text-white shadow-floating">
            {p.discountPct}% OFF
          </span>
        ) : null}
      </span>

      {/* Info */}
      <span className="flex flex-1 flex-col p-sm">
        <span className="line-clamp-2 text-[12.5px] font-semibold leading-tight text-ink">
          {p.name}
        </span>

        {/* Rating */}
        {p.ratingCount > 0 ? (
          <span className="mt-xs flex items-center gap-[3px]">
            <span className="flex items-center gap-[2px] rounded-[3px] bg-success px-[5px] py-[2px]">
              <span className="text-[10px] font-extrabold text-white">
                {p.ratingAvg.toFixed(1)}
              </span>
              <Star size={9} className="fill-white text-white" aria-hidden />
            </span>
            <span className="text-[10px] text-muted">
              ({p.ratingCount > 999 ? `${(p.ratingCount / 1000).toFixed(1)}k` : p.ratingCount})
            </span>
          </span>
        ) : null}

        {/* Prices */}
        <span className="mt-sm flex items-baseline gap-[4px]">
          <span className="text-[15px] font-extrabold leading-none text-ink">
            {formatINR(priceShown)}
          </span>
          {priceCrossed > 0 ? (
            <span className="text-[11px] text-muted line-through">{formatINR(priceCrossed)}</span>
          ) : null}
        </span>

        {saves > 0 ? (
          <span className="mt-[2px] text-[10px] font-bold text-success">
            You save {formatINR(saves)}
          </span>
        ) : null}
      </span>
    </Link>
  );
}
