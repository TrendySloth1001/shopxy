"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Star } from "@/shared/icons";
import { ImageBox } from "@/features/home/components/image-box";
import { formatINR } from "@/shared/format";
import { fetchFbt } from "../api";
import type { FbtCard } from "../types";

interface Props {
  productId: number;
}

export function PdpFbtRail({ productId }: Props) {
  const [items, setItems] = useState<FbtCard[] | null>(null);

  useEffect(() => {
    void fetchFbt(productId).then(setItems);
  }, [productId]);

  if (items === null || items.length === 0) return null;

  return (
    <div className="py-md">
      <p className="mb-sm px-lg text-title-sm font-extrabold text-ink">
        Frequently bought together
      </p>
      <div className="flex gap-sm overflow-x-auto px-lg pb-sm scrollbar-none">
        {items.map((item) => {
          const imageUrl = item.images[0]?.url ?? "";
          const isDiscounted = item.mrp > item.sellingPrice;
          return (
            <Link
              key={item.id}
              href={`/p/${item.id}`}
              className="group flex w-36 shrink-0 flex-col overflow-hidden rounded-md border border-hairline bg-white transition-shadow hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
            >
              <span className="relative block aspect-square w-full bg-canvas">
                <ImageBox url={imageUrl} alt={item.name} />
              </span>
              <div className="flex flex-col p-sm">
                <p className="line-clamp-2 text-[12px] font-semibold leading-snug text-ink">
                  {item.name}
                </p>
                <div className="mt-xs flex items-baseline gap-xs">
                  <span className="text-[14px] font-extrabold text-ink">
                    {formatINR(item.sellingPrice)}
                  </span>
                  {isDiscounted ? (
                    <span className="text-[11px] text-muted line-through">
                      {formatINR(item.mrp)}
                    </span>
                  ) : null}
                </div>
                {item.ratingAvg != null ? (
                  <div className="mt-xs flex items-center gap-[2px]">
                    <Star size={11} className="fill-[#E05A2A] text-[#E05A2A]" aria-hidden />
                    <span className="text-[11px] font-semibold text-muted">
                      {item.ratingAvg.toFixed(1)} ({item.ratingCount})
                    </span>
                  </div>
                ) : null}
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
