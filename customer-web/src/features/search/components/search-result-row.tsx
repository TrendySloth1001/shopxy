"use client";

import Link from "next/link";
import { Star } from "lucide-react";
import { ImageBox } from "@/features/home/components/image-box";
import { formatINR } from "@/shared/format";
import type { SearchHit } from "../types";

/** Single result row — thumbnail + name + shop + rating + price. */
export function SearchResultRow({
  hit,
  onTap,
}: {
  hit: SearchHit;
  onTap?: () => void;
}) {
  return (
    <Link
      href={`/p/${hit.id}`}
      onClick={onTap}
      className="flex items-center gap-md py-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {/* Thumbnail */}
      <span className="relative size-16 shrink-0 overflow-hidden rounded-sm border border-hairline bg-hero-panel">
        <ImageBox url={hit.imageUrl} alt={hit.name} />
      </span>

      {/* Text */}
      <span className="min-w-0 flex-1">
        <span className="block line-clamp-2 text-[13.5px] font-semibold leading-tight text-ink">
          {hit.name}
        </span>
        {hit.shopName ? (
          <span className="mt-[2px] block text-[11px] font-bold text-brand">
            by {hit.shopName}
          </span>
        ) : null}
        {hit.ratingAvg != null && hit.ratingCount > 0 ? (
          <span className="mt-[2px] flex items-center gap-[2px]">
            <Star size={10} className="fill-success text-success" aria-hidden />
            <span className="text-[10px] font-semibold text-muted">
              {hit.ratingAvg.toFixed(1)} ({hit.ratingCount})
            </span>
          </span>
        ) : null}
      </span>

      {/* Price */}
      <span className="shrink-0 text-[15px] font-extrabold leading-none text-ink">
        {formatINR(hit.sellingPrice)}
      </span>
    </Link>
  );
}
