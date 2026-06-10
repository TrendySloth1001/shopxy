import Link from "next/link";
import type { CollectionTile } from "../types";
import { ImageBox } from "./image-box";
import { searchHref } from "./product-carousel";

/** Tap destination for a collection tile — the collection page is future work. */
function collectionHref(t: CollectionTile): string {
  return t.slug ? `/collection/${t.slug}` : searchHref(t.label);
}

/**
 * Editorial collection banner — port of `HomeCollectionBanner`. Bright yellow
 * panel with a title/subtitle, an "0% EMI" badge, and up to four square
 * collection tiles.
 */
export function CollectionBanner({ title, tiles }: { title: string; tiles: CollectionTile[] }) {
  const shown = tiles.slice(0, 4);
  if (shown.length === 0) return null;
  return (
    <section className="px-lg">
      <div className="rounded-lg bg-spotlight p-lg">
        <div className="flex items-start justify-between gap-md">
          <div className="min-w-0">
            <h2 className="text-[18px] font-extrabold text-ink">{title || "Editorial Collection"}</h2>
            <p className="mt-[2px] text-[12px] text-ink/80">Curated picks from our editors</p>
          </div>
          <span className="shrink-0 rounded-xs bg-ink px-sm py-[2px] text-[11px] font-extrabold text-spotlight">
            0% EMI
          </span>
        </div>
        <div className="mt-md grid grid-cols-4 gap-sm">
          {shown.map((t) => (
            <Link key={t.collectionId} href={collectionHref(t)} className="group flex flex-col gap-xs">
              <span className="relative block aspect-square w-full overflow-hidden rounded-md">
                <ImageBox url={t.imageUrl} alt={t.label} placeholderColor="#FFFFFF" />
              </span>
              <span className="line-clamp-1 text-[11px] font-semibold text-ink">{t.label}</span>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}
