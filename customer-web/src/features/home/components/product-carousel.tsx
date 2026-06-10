import type { ProductCard } from "../types";
import { ProductTile } from "./product-tile";
import { SectionHeader } from "./section-header";

/** Search destination for a "see all" — the dedicated section page is future work. */
export function searchHref(query: string): string {
  return `/search?q=${encodeURIComponent(query)}`;
}

/**
 * Horizontal product rail — port of `HomeProductCarousel`. Header (eyebrow +
 * title + circular see-all) over a horizontally-scrolling row of product tiles.
 */
export function ProductCarousel({
  eyebrow,
  title,
  products,
  source = "home",
}: {
  eyebrow?: string;
  title: string;
  products: ProductCard[];
  source?: string;
}) {
  if (products.length === 0) return null;
  return (
    <section>
      <SectionHeader eyebrow={eyebrow} title={title} seeAllHref={searchHref(title)} variant="circle" />
      <div className="mt-md flex gap-md overflow-x-auto px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {products.map((p) => (
          <div key={p.productId} className="w-[158px] shrink-0">
            <ProductTile product={p} source={source} />
          </div>
        ))}
      </div>
    </section>
  );
}
