import Link from "next/link";
import type { ProductCard } from "../types";
import { ImageBox } from "./image-box";
import { productHref } from "./product-tile";

/**
 * "Pick up where you left off" rail — port of `HomeRecentlyViewed`. Horizontal
 * row of wide tiles (square thumbnail + name + price) from the personalised
 * recently-viewed list.
 */
export function RecentlyViewed({ items }: { items: ProductCard[] }) {
  if (items.length === 0) return null;
  return (
    <section>
      <div className="flex items-center justify-between px-lg">
        <h2 className="text-[17px] font-extrabold text-ink">Pick up where you left off</h2>
      </div>
      <div className="mt-md flex gap-md overflow-x-auto px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {items.map((p) => (
          <Link
            key={p.productId}
            href={productHref(p.productId)}
            className="flex w-[220px] shrink-0 items-center gap-sm rounded-md bg-white p-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <span className="relative block size-[84px] shrink-0 overflow-hidden rounded-sm">
              <ImageBox url={p.imageUrl} alt={p.name} placeholderColor={p.bgColor} />
            </span>
            <span className="flex min-w-0 flex-1 flex-col">
              <span className="line-clamp-2 text-[12px] leading-tight text-ink">{p.name}</span>
              <span className="mt-xs text-[14px] font-extrabold text-ink">{p.price}</span>
              {p.originalPrice ? (
                <span className="text-[10px] text-muted line-through">{p.originalPrice}</span>
              ) : null}
            </span>
          </Link>
        ))}
      </div>
    </section>
  );
}
