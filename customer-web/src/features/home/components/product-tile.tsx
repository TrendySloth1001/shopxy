"use client";

import Link from "next/link";
import { Heart, Star, Truck } from "lucide-react";
import { isAssured, type ProductCard } from "../types";
import { recordTap } from "../tracking";
import { ImageBox } from "./image-box";

/** Destination for a product tap — the canonical PDP route. */
export function productHref(id: number): string {
  return `/p/${id}`;
}

/**
 * The workhorse product card — port of the Flutter `HomeProductTile`. Fills its
 * parent's width (carousels wrap it in a fixed-width slot, grids in a cell).
 * Image with AD / discount / wishlist / rating overlays + name, price and a
 * bank-price / free-delivery line.
 *
 * Follows the shared PRODUCT CARD SPEC:
 *   container  rounded-lg border-hairline bg-white hover:shadow-floating hover:-translate-y-[2px]
 *   image      group-hover:scale-[1.04] object-cover
 *   badge      bg-brand text-white text-[11px] font-extrabold rounded-sm
 *   rating     bg-success text-white rounded-sm chip
 *   price      bold selling price, muted line-through MRP, green % off
 */
export function ProductTile({ product, source = "home" }: { product: ProductCard; source?: string }) {
  const p = product;
  const discounted = p.discountPct > 0;
  const hasImage = !!p.imageUrl;
  const initial = (p.name[0] ?? "?").toUpperCase();

  return (
    <Link
      href={productHref(p.productId)}
      onClick={() => recordTap(p.productId, source)}
      className="group flex w-full flex-col overflow-hidden rounded-lg border border-hairline bg-white transition-all duration-200 hover:-translate-y-[2px] hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {/* ── Image area ────────────────────────────────────────────────────── */}
      <span className="relative block aspect-square w-full overflow-hidden bg-canvas">
        {hasImage ? (
          <span className="block size-full transition-transform duration-300 group-hover:scale-[1.04]">
            <ImageBox url={p.imageUrl} alt={p.name} placeholderColor={p.bgColor} />
          </span>
        ) : (
          /* Brand-soft placeholder with first-letter monogram */
          <span className="flex size-full items-center justify-center bg-brand-soft">
            <span className="text-[28px] font-extrabold leading-none text-brand">{initial}</span>
          </span>
        )}

        {/* AD badge */}
        {p.isAd ? (
          <span className="absolute left-[6px] top-[6px] rounded-xs bg-white/90 px-[5px] py-[1px] text-[9px] font-extrabold tracking-[0.4px] text-muted">
            AD
          </span>
        ) : null}

        {/* Discount badge — top-left per spec */}
        {discounted ? (
          <span
            className="absolute left-[6px] rounded-sm bg-brand px-sm py-[2px] text-[11px] font-extrabold tracking-[0.3px] text-white"
            style={{ top: p.isAd ? 28 : 6 }}
          >
            {p.discountPct}% OFF
          </span>
        ) : null}

        {/* Wishlist heart — white circular chip with hover scale + filled transition */}
        <span className="absolute right-[6px] top-[6px] flex size-7 items-center justify-center rounded-full bg-white/95 shadow-floating transition-transform duration-200 hover:scale-110 active:scale-95">
          <Heart
            size={14}
            className="transition-all duration-200 text-muted group-hover:text-brand"
            aria-hidden
          />
        </span>

        {/* Tag chip */}
        {p.tag ? (
          <span className="absolute bottom-[30px] left-[6px] rounded-xs bg-ink px-[6px] py-[2px] text-[9px] font-bold text-white">
            {p.tag}
          </span>
        ) : null}

        {/* Rating chip — bg-success per spec */}
        {p.ratingCountRaw > 0 ? (
          <span className="absolute bottom-[6px] left-[6px] inline-flex items-center gap-[3px] rounded-sm bg-success px-[6px] py-[2px] text-[11px] font-bold text-white">
            {p.rating.toFixed(1)}
            <Star size={10} className="fill-white text-white" aria-hidden />
            <span className="text-[9px] font-normal text-white/80">{p.ratingCount}</span>
          </span>
        ) : null}
      </span>

      {/* ── Text area ─────────────────────────────────────────────────────── */}
      <span className="flex flex-col p-sm">
        <span className="line-clamp-2 text-[12.5px] font-semibold leading-tight text-ink">{p.name}</span>

        {/* Price row: bold selling price, muted line-through MRP, green % off */}
        <span className="mt-xs flex items-baseline gap-[4px]">
          <span className="text-[15px] font-extrabold leading-none text-ink">{p.price}</span>
          {p.originalPrice ? (
            <span className="text-[11px] text-muted line-through">{p.originalPrice}</span>
          ) : null}
          {discounted ? (
            <span className="text-[11px] font-bold text-brand">{p.discountPct}% off</span>
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
