import Link from "next/link";
import type { BrandSpotlight } from "@/features/home/types";
import { ImageBox } from "@/features/home/components/image-box";

function SpotlightCard({ spotlight }: { spotlight: BrandSpotlight }) {
  const s = spotlight;
  const href = s.shopSlug ? `/shop/${s.shopSlug}` : `/search?q=${encodeURIComponent(s.brand || "")}`;

  return (
    <Link
      href={href}
      className="group relative block w-full overflow-hidden rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      style={{ backgroundColor: s.bgColor, aspectRatio: "21/6", maxHeight: "240px" }}
    >
      {/* Background image */}
      <ImageBox url={s.imageUrl} alt={s.brand} placeholderColor={s.bgColor} />

      {/* Gradient overlay */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "linear-gradient(to bottom, rgba(0,0,0,0.1), transparent 40%, rgba(0,0,0,0.6))",
        }}
      />

      {/* Copy */}
      <div className="absolute inset-x-md bottom-md">
        {s.dealLabel ? (
          <span className="mb-sm inline-block rounded-xs bg-spotlight px-sm py-[4px] text-[12px] font-extrabold text-ink">
            {s.dealLabel}
          </span>
        ) : null}
        {s.brand ? (
          <p className="text-[16px] font-extrabold leading-tight text-white [text-shadow:0_1px_6px_rgba(0,0,0,0.4)]">
            {s.brand}
          </p>
        ) : null}
        {s.subtitle ? (
          <p className="mt-[2px] line-clamp-2 text-[12px] font-medium leading-snug text-white/90 [text-shadow:0_1px_4px_rgba(0,0,0,0.3)]">
            {s.subtitle}
          </p>
        ) : null}
      </div>
    </Link>
  );
}

/** Vertical list of brand-spotlight cards — mirrors the Flutter `_Spotlights`. */
export function SpotlightsList({ spotlights }: { spotlights: BrandSpotlight[] }) {
  if (spotlights.length === 0) return null;
  return (
    <section>
      <h2 className="mb-md text-[17px] font-extrabold text-ink">Brands in Spotlight</h2>
      <div className="grid grid-cols-1 gap-md lg:grid-cols-2">
        {spotlights.map((s) => (
          <SpotlightCard key={s.spotlightId} spotlight={s} />
        ))}
      </div>
    </section>
  );
}
