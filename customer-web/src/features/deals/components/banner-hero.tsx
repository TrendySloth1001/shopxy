import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import type { BannerMeta } from "../types";
import { ImageBox } from "@/features/home/components/image-box";
import { withAlpha } from "@/features/home/format";

/**
 * Hero section for the banner detail page.
 * Full-bleed image with gradient overlay + brand label, title, subtitle, and
 * CTA button. Parallels the Flutter `_HeroSliver` in `banner_slide_detail_page.dart`.
 */
export function BannerHero({
  banner,
  productCount,
}: {
  banner: BannerMeta;
  productCount: number;
}) {
  const { title, subtitle, brandLabel, eyebrow, imageUrl, bgColor, accentColor, ctaTarget } =
    banner;
  const displayBrand = brandLabel || eyebrow;

  return (
    <div className="relative h-[300px] w-full overflow-hidden sm:h-[380px]" style={{ backgroundColor: bgColor }}>
      {/* Background image */}
      <ImageBox url={imageUrl} alt={title} placeholderColor={bgColor} />

      {/* Dark gradient for legibility */}
      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(to bottom, ${withAlpha("#000000", 0.22)}, ${withAlpha("#000000", 0.05)} 45%, ${withAlpha("#000000", 0.78)})`,
        }}
      />

      {/* Back button — circle affordance floating over the hero */}
      <Link
        href="/deals"
        aria-label="Back to deals"
        className="absolute left-lg top-lg z-10 flex size-9 items-center justify-center rounded-full bg-black/35 text-white transition-opacity hover:bg-black/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/60"
      >
        <ArrowLeft size={18} aria-hidden />
      </Link>

      {/* Copy anchored to the bottom */}
      <div className="absolute inset-x-lg bottom-lg flex flex-col items-start gap-sm">
        {displayBrand ? (
          <span
            className="rounded-xs px-sm py-[3px] text-[11px] font-extrabold uppercase tracking-[0.8px] text-white"
            style={{ backgroundColor: accentColor }}
          >
            {displayBrand}
          </span>
        ) : null}

        {title ? (
          <p className="text-[22px] font-extrabold leading-tight text-white [text-shadow:0_2px_8px_rgba(0,0,0,0.4)] sm:text-[26px]">
            {title}
          </p>
        ) : null}

        {subtitle ? (
          <p className="line-clamp-2 text-[13px] leading-snug text-white/90 [text-shadow:0_1px_4px_rgba(0,0,0,0.35)]">
            {subtitle}
          </p>
        ) : null}

        <div className="flex items-center gap-sm">
          {banner.ctaText && ctaTarget ? (
            <Link
              href={ctaTarget.startsWith("http") ? ctaTarget : `/${ctaTarget.replace(/^\//, "")}`}
              className="rounded-full bg-white px-md py-[6px] text-[13px] font-extrabold text-ink transition-opacity hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/60"
            >
              {banner.ctaText}
            </Link>
          ) : banner.ctaText ? (
            <span className="rounded-full bg-white px-md py-[6px] text-[13px] font-extrabold text-ink">
              {banner.ctaText}
            </span>
          ) : null}

          {productCount > 0 ? (
            <span className="rounded-full bg-black/35 px-sm py-[4px] text-[11px] font-extrabold uppercase tracking-[0.6px] text-white">
              {productCount} items
            </span>
          ) : null}
        </div>
      </div>
    </div>
  );
}
