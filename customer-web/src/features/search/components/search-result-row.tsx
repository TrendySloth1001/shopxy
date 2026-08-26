"use client";

import { useState } from "react";
import Link from "next/link";
import { Star } from "@/shared/icons";
import { formatINR } from "@/shared/format";
import { mediaSrc } from "@/shared/media";
import type { SearchHit } from "../types";

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
      className="flex items-center gap-md rounded-lg px-sm py-sm transition-all duration-200 hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="relative size-16 shrink-0 overflow-hidden rounded-lg border border-hairline bg-hero-panel">
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
          <span className="block size-full bg-hero-panel" aria-hidden />
        )}
      </span>

      <span className="flex min-w-0 flex-1 items-start gap-sm">
        <span className="min-w-0 flex-1">
          <span className="block line-clamp-2 text-[13.5px] font-semibold leading-tight text-ink">
            {hit.name}
          </span>
          {hit.shopName ? (
            <span className="mt-xxs block text-caption font-bold text-brand">
              by {hit.shopName}
            </span>
          ) : null}
          {hit.ratingAvg != null && hit.ratingCount > 0 ? (
            <span className="mt-[3px] inline-flex items-center gap-[3px]">
              <span className="inline-flex items-center gap-xxs rounded-sm bg-success px-[5px] py-xxs text-micro font-bold text-white">
                {hit.ratingAvg.toFixed(1)}
                <Star size={8} className="fill-white text-white" aria-hidden />
              </span>
              <span className="text-micro text-muted">
                ({hit.ratingCount > 999 ? `${(hit.ratingCount / 1000).toFixed(1)}k` : hit.ratingCount})
              </span>
            </span>
          ) : null}
        </span>

        <span className="shrink-0 text-right">
          <span className="block text-[15px] font-extrabold leading-none text-ink">
            {formatINR(hit.sellingPrice)}
          </span>
        </span>
      </span>
    </Link>
  );
}
