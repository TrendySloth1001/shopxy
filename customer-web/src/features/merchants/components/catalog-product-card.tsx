"use client";

import Image from "next/image";
import { Package } from "lucide-react";
import type { CatalogProduct } from "../types";
import { formatINR } from "@/shared/format";

type CatalogProductCardProps = {
  product: CatalogProduct;
};

export function CatalogProductCard({ product }: CatalogProductCardProps) {
  const firstImage = product.images[0] ?? null;
  const imgSrc = firstImage
    ? firstImage.url.startsWith("/images/")
      ? `/api/media${firstImage.url}`
      : firstImage.url
    : null;

  const hasSalePrice =
    product.sellingPrice != null &&
    product.mrp != null &&
    product.sellingPrice < product.mrp;
  const displayPrice = product.sellingPrice ?? product.mrp;

  return (
    <div className="group overflow-hidden rounded-lg border border-hairline bg-white">
      {/* Product image */}
      <div className="relative aspect-square overflow-hidden bg-hero-panel">
        {imgSrc ? (
          <Image
            src={imgSrc}
            alt={product.name}
            fill
            className="object-contain p-sm transition-transform duration-short group-hover:scale-105"
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 200px"
          />
        ) : (
          <div className="flex h-full w-full items-center justify-center">
            <Package size={32} className="text-disabled" />
          </div>
        )}
      </div>

      {/* Info */}
      <div className="px-md py-sm">
        {product.category && (
          <p className="mb-[2px] text-label-md font-bold text-brand line-clamp-1">
            {product.category.name}
          </p>
        )}
        <p className="text-title-sm font-bold text-ink line-clamp-2 leading-snug">
          {product.name}
        </p>
        {product.sku && (
          <p className="mt-[2px] text-body-sm text-muted">
            SKU: {product.sku}
          </p>
        )}
        <div className="mt-sm flex flex-wrap items-baseline gap-xs">
          {displayPrice != null && (
            <span className="text-title-sm font-extrabold text-ink">
              {formatINR(displayPrice)}
            </span>
          )}
          {hasSalePrice && product.mrp != null && (
            <span className="text-body-sm text-muted line-through">
              {formatINR(product.mrp)}
            </span>
          )}
          {product.unit && (
            <span className="text-body-sm text-muted">/{product.unit}</span>
          )}
        </div>
        {product.taxPercent != null && product.taxPercent > 0 && (
          <p className="mt-[2px] text-body-sm text-muted">
            +{product.taxPercent}% GST
          </p>
        )}
      </div>
    </div>
  );
}

// ─── Skeleton ─────────────────────────────────────────────────────────────

export function CatalogProductCardSkeleton() {
  return (
    <div className="overflow-hidden rounded-lg border border-hairline bg-white">
      <div className="aspect-square animate-pulse bg-hero-panel" />
      <div className="px-md py-sm">
        <div className="h-3 w-1/2 animate-pulse rounded-full bg-hero-panel" />
        <div className="mt-xs h-4 w-full animate-pulse rounded-full bg-hero-panel" />
        <div className="mt-[3px] h-3 w-3/4 animate-pulse rounded-full bg-hero-panel" />
        <div className="mt-sm h-5 w-1/2 animate-pulse rounded-full bg-hero-panel" />
      </div>
    </div>
  );
}
