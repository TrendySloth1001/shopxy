"use client";

import { useState } from "react";
import Link from "next/link";
import { Star } from "lucide-react";
import { formatINR } from "@/shared/format";
import { mediaSrc } from "@/shared/media";
import type { SearchHit } from "../types";

/** Single result row — thumbnail + name + shop + rating + price. */
export function SearchResultRow({
  hit,
  onTap,
}: {
  hit: SearchHit;
  onTap?: () => void;
}) {
  const [imgErrored, setImgErrored] = useState(false);
  const thumbSrc = mediaSrc(hit.imageUrl);

  return (
    <Link
      href={`/p/${hit.id}`}
      onClick={onTap}
      className="flex items-center gap-md py-md transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      {/* Thumbnail — mediaSrc routes relative keys through /api/media proxy;
          onError shows a neutral placeholder box (no broken-image glyph). */}
      <span className="relative size-16 shrink-0 overflow-hidden rounded-sm border border-hairline bg-hero-panel">
        {thumbSrc && !imgErrored ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={thumbSrc}
            alt={hit.name}
            className="size-full object-cover"
            loading="lazy"
            decoding="async"
            onError={() => setImgErrored(true)}
          />
        ) : (
          // Neutral placeholder — no broken-image glyph
          <span className="block size-full bg-hero-panel" aria-hidden />
        )}
      </span>

      {/* Text + price — flex row keeps price anchored right without floating
          at wide widths; the text column is min-w-0 so it truncates. */}
      <span className="flex min-w-0 flex-1 items-center gap-sm">
        {/* Name / shop / rating */}
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

        {/* Price — backend search hits expose only sellingPrice (no mrp field);
            MRP strikethrough will be added here when the backend exposes it. */}
        <span className="shrink-0 text-right">
          <span className="block text-[15px] font-extrabold leading-none text-ink">
            {formatINR(hit.sellingPrice)}
          </span>
        </span>
      </span>
    </Link>
  );
}
