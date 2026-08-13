"use client";

import Link from "next/link";
import { Heart, ShieldCheck, Star, Truck } from "@/shared/icons";
import { isAssured, type ProductCard } from "../types";
import { recordTap } from "../tracking";
import { ImageBox } from "./image-box";

/** Destination for a product tap — the canonical PDP route. */
export function productHref(id: string): string {
  return `/p/${id}`;
}

/**
 * The workhorse product card — port of the Flutter `HomeProductTile`. Fills its
 * parent's width (carousels wrap it in a fixed-width slot, grids in a cell).
 * Image with AD / discount / wishlist / rating overlays + name, price and a
 * bank-price / free-delivery line.
 *
 * Follows the shared PRODUCT CARD SPEC:
 *   container  rounded-lg border-hairline bg-white hover:shadow-floating hover:-translate-y-xxs
 *   image      group-hover:scale-[1.04] object-cover
 *   badge      bg-brand text-white text-caption font-extrabold rounded-sm
 *   rating     bg-success text-white rounded-sm chip
 *   price      bold selling price, muted line-through MRP, green % off
 */
export function ProductTile({
  product,
  source = "home",
  priority = false,
}: {
  product: ProductCard;
  source?: string;
  /** Set for the first above-the-fold tiles so their image is the eager LCP. */
  priority?: boolean;
}) {
  const p = product;
  const discounted = p.discountPct > 0;
  const hasImage = !!p.imageUrl;
  const initial = (p.name[0] ?? "?").toUpperCase();

  return (
    <Link
      href={productHref(p.productId)}
      onClick={() => recordTap(p.productId, source)}
      className="group flex w-full flex-col overflow-hidden rounded-lg border border-hairline bg-white transition-all duration-200 hover:-translate-y-xxs hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {/* ── Image area ────────────────────────────────────────────────────── */}
      <span className="relative block aspect-square w-full overflow-hidden bg-canvas">
        {hasImage ? (
          <span className="block size-full transition-transform duration-300 group-hover:scale-[1.04]">
            <ImageBox url={p.imageUrl} alt={p.name} placeholderColor={p.bgColor} priority={priority} />
          </span>
        ) : (
          /* Brand-soft placeholder with first-letter monogram */
          <span className="flex size-full items-center justify-center bg-brand-soft">
            <span className="text-[34px] font-extrabold leading-none text-brand/70">{initial}</span>
          </span>
        )}

        {/* Discount badge — top-left, the strongest sell signal */}
        {discounted ? (
          <span className="absolute left-[8px] top-[8px] rounded-sm bg-brand px-sm py-xxs text-caption font-extrabold tracking-[0.3px] text-white shadow-floating">
            {p.discountPct}% OFF
          </span>
        ) : null}

        {/* Wishlist heart — white circular chip */}
        <span className="absolute right-[8px] top-[8px] flex size-7 items-center justify-center rounded-full bg-white/95 shadow-floating transition-transform duration-200 hover:scale-110 active:scale-95">
          <Heart
            size={14}
            className="transition-all duration-200 text-muted group-hover:text-brand"
            aria-hidden
          />
        </span>

        {/* Tag ribbon (Bestseller / New …) — bottom-left over the image */}
        {p.tag ? (
          <span className="absolute bottom-[8px] left-[8px] rounded-xs bg-ink/85 px-[6px] py-xxs text-nano font-extrabold uppercase tracking-[0.4px] text-white backdrop-blur-sm">
            {p.tag}
          </span>
        ) : null}
      </span>

      {/* ── Text area ─────────────────────────────────────────────────────── */}
      <span className="flex flex-1 flex-col p-md">
        {/* Brand eyebrow — adds identity when present */}
        {p.brand ? (
          <span className="mb-[1px] truncate text-micro font-extrabold uppercase tracking-[0.5px] text-muted">
            {p.brand}
          </span>
        ) : null}

        <span className="line-clamp-2 text-[13.5px] font-semibold leading-tight text-ink">{p.name}</span>

        {/* Seller line — "by <shop>" */}
        {p.shopName ? (
          <span className="mt-xxs truncate text-caption text-muted">
            by <span className="font-semibold text-ink/75">{p.shopName}</span>
          </span>
        ) : null}

        {/* Rating — moved into the body so it shows even without a photo */}
        {p.ratingCountRaw > 0 ? (
          <span className="mt-[5px] flex items-center gap-[5px]">
            <span className="inline-flex items-center gap-[3px] rounded-sm bg-success px-[6px] py-xxs text-caption font-bold text-white">
              {p.rating.toFixed(1)}
              <Star size={9} className="fill-white text-white" aria-hidden />
            </span>
            <span className="text-caption text-muted">({p.ratingCount})</span>
          </span>
        ) : null}

        {/* Price row: bold selling price, muted line-through MRP, green % off */}
        <span className="mt-[6px] flex flex-wrap items-baseline gap-x-[5px] gap-y-[1px]">
          <span className="text-body-lg font-extrabold leading-none text-ink">{p.price}</span>
          {p.originalPrice ? (
            <span className="text-caption text-muted line-through">{p.originalPrice}</span>
          ) : null}
          {discounted ? (
            <span className="text-caption font-bold text-brand">{p.discountPct}% off</span>
          ) : null}
        </span>

        {/* Delivery + assurance — pinned to the card bottom so every card aligns */}
        {p.freeDelivery || isAssured(p) ? (
          <span className="mt-auto flex items-center gap-[6px] pt-[6px]">
            {p.freeDelivery ? (
              <span className="flex items-center gap-[3px] text-micro font-extrabold tracking-[0.2px] text-success">
                <Truck size={11} aria-hidden /> Free delivery
              </span>
            ) : null}
            {isAssured(p) ? (
              <span className="inline-flex items-center gap-xxs rounded-xs bg-info/10 px-[4px] py-[1px] text-nano font-extrabold tracking-[0.3px] text-info">
                <ShieldCheck size={9} aria-hidden /> ASSURED
              </span>
            ) : null}
          </span>
        ) : null}
      </span>
    </Link>
  );
}
