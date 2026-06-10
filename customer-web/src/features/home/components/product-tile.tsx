"use client";

import Link from "next/link";
import { Heart, Star, Truck } from "lucide-react";
import { isAssured, type ProductCard } from "../types";
import { recordTap } from "../tracking";
import { ImageBox } from "./image-box";

/** Destination for a product tap. The PDP page is future work (see PENDING). */
export function productHref(id: number): string {
  return `/product/${id}`;
}

/**
 * The workhorse product card — port of the Flutter `HomeProductTile`. Fills its
 * parent's width (carousels wrap it in a fixed-width slot, grids in a cell).
 * Image with AD / discount / wishlist / rating overlays + name, price and a
 * bank-price / free-delivery line.
 */
export function ProductTile({ product, source = "home" }: { product: ProductCard; source?: string }) {
  const p = product;
  const discounted = p.discountPct > 0;
  return (
    <Link
      href={productHref(p.productId)}
      onClick={() => recordTap(p.productId, source)}
      className="group flex w-full flex-col overflow-hidden rounded-md border border-hairline bg-white transition-shadow hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="relative block aspect-square w-full">
        <ImageBox url={p.imageUrl} alt={p.name} placeholderColor={p.bgColor} />

        {p.isAd ? (
          <span className="absolute left-[6px] top-[6px] rounded-xs bg-white/90 px-[5px] py-[1px] text-[9px] font-extrabold tracking-[0.4px] text-muted">
            AD
          </span>
        ) : null}
        {discounted ? (
          <span
            className="absolute left-[6px] rounded-xs bg-gradient-to-br from-brand to-brand-strong px-[6px] py-[2px] text-[10px] font-extrabold tracking-[0.4px] text-white shadow-floating"
            style={{ top: p.isAd ? 28 : 6 }}
          >
            {p.discountPct}% OFF
          </span>
        ) : null}

        <span className="absolute right-[6px] top-[6px] flex size-7 items-center justify-center rounded-full bg-white/95 shadow-floating">
          <Heart size={15} className="text-ink" aria-hidden />
        </span>

        {p.tag ? (
          <span className="absolute bottom-[30px] left-[6px] rounded-xs bg-ink px-[6px] py-[2px] text-[9px] font-bold text-white">
            {p.tag}
          </span>
        ) : null}

        {p.ratingCountRaw > 0 ? (
          <span className="absolute bottom-[6px] left-[6px] flex items-center gap-[2px] rounded-[3px] bg-white px-[6px] py-[2px] shadow-floating">
            <span className="text-[11px] font-extrabold text-ink">{p.rating.toFixed(1)}</span>
            <Star size={12} className="fill-success text-success" aria-hidden />
            <span className="text-[9px] font-semibold text-muted">{p.ratingCount}</span>
          </span>
        ) : null}
      </span>

      <span className="flex flex-col p-sm">
        <span className="line-clamp-2 text-[12.5px] font-semibold leading-tight text-ink">{p.name}</span>
        <span className="mt-xs flex items-baseline gap-[4px]">
          <span className="text-[15px] font-extrabold leading-none text-ink">{p.price}</span>
          {p.originalPrice ? (
            <span className="text-[11px] text-muted line-through">{p.originalPrice}</span>
          ) : null}
        </span>

        {discounted ? (
          <span className="mt-[2px] flex items-center gap-[4px] text-[11px] font-bold leading-tight text-info">
            <span>{p.bankPrice} with Bank</span>
            {p.freeDelivery ? (
              <span className="font-extrabold tracking-[0.2px] text-success">· FREE</span>
            ) : null}
          </span>
        ) : p.freeDelivery || isAssured(p) ? (
          <span className="mt-[2px] flex items-center gap-[6px]">
            {p.freeDelivery ? (
              <span className="flex items-center gap-[2px] text-[10px] font-extrabold tracking-[0.2px] text-success">
                <Truck size={10} aria-hidden /> FREE delivery
              </span>
            ) : null}
            {isAssured(p) ? (
              <span className="rounded-xs bg-info/10 px-[4px] py-[1px] text-[9px] font-extrabold tracking-[0.3px] text-info">
                ASSURED
              </span>
            ) : null}
          </span>
        ) : null}
      </span>
    </Link>
  );
}
