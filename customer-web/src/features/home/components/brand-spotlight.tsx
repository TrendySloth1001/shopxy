import Link from "next/link";
import { ChevronRight } from "lucide-react";
import type { BrandSpotlight } from "../types";
import { ImageBox } from "./image-box";
import { searchHref } from "./product-carousel";

/** Tap destination for a spotlight card. */
function spotlightHref(s: BrandSpotlight): string {
  if (s.shopSlug) return `/shop/${s.shopSlug}`;
  return searchHref(s.brand || s.subtitle || "");
}

/**
 * Brand-in-spotlight card — port of `HomeBrandSpotlight`. Full-bleed brand
 * image on a coloured panel with a brand label, AD badge, highlight deal label
 * and subtitle. Image gently scales on hover inside the rounded-lg container.
 */
export function BrandSpotlightCard({ spotlight }: { spotlight: BrandSpotlight }) {
  const s = spotlight;
  return (
    <section>
      <div className="flex items-center justify-between px-lg">
        <h2 className="text-title-md font-extrabold text-ink">Brands in Spotlight</h2>
        <Link
          href="/spotlights"
          className="flex items-center gap-[2px] text-[12px] font-bold text-brand transition-colors duration-200 hover:text-brand-strong focus-visible:outline-none focus-visible:underline"
        >
          View all <ChevronRight size={16} aria-hidden />
        </Link>
      </div>
      <div className="mt-md px-lg">
        <Link
          href={spotlightHref(s)}
          className="group relative block h-[220px] w-full overflow-hidden rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          style={{ backgroundColor: s.bgColor }}
        >
          {/* Image scales gently on hover inside the rounded-lg container */}
          <span className="block size-full transition-transform duration-300 group-hover:scale-[1.03]">
            <ImageBox url={s.imageUrl} alt={s.brand} placeholderColor={s.bgColor} />
          </span>
          <div
            className="absolute inset-0"
            style={{
              background: "linear-gradient(to bottom, rgba(0,0,0,0.2), transparent 40%, rgba(0,0,0,0.55))",
            }}
          />
          {s.brand ? (
            <span className="absolute left-md top-md rounded-xs bg-white/95 px-[8px] py-[3px] text-[11px] font-extrabold tracking-[0.5px] text-ink">
              {s.brand}
            </span>
          ) : null}
          <span className="absolute right-md top-md rounded-xs bg-white/70 px-[6px] py-[2px] text-[9px] font-bold tracking-[0.5px] text-muted">
            AD
          </span>
          <div className="absolute inset-x-md bottom-md">
            {s.dealLabel ? (
              <span className="mb-sm inline-block rounded-xs bg-spotlight px-[12px] py-[6px] text-[13px] font-extrabold text-ink">
                {s.dealLabel}
              </span>
            ) : null}
            {s.subtitle ? (
              <p className="line-clamp-2 text-[13px] font-semibold leading-snug text-white [text-shadow:0_1px_4px_rgba(0,0,0,0.54)]">
                {s.subtitle}
              </p>
            ) : null}
          </div>
        </Link>
      </div>
    </section>
  );
}
