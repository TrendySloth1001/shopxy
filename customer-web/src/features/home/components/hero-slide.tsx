import Link from "next/link";
import type { HeroSlide } from "../types";
import { ImageBox } from "./image-box";

/** Tap destination for a banner. Falls back to the home page when the
 *  merchant didn't set a link. */
export function slideHref(slide: HeroSlide): string {
  return slide.linkUrl && slide.linkUrl.length > 0 ? slide.linkUrl : "/";
}

/**
 * A banner is just the merchant's uploaded image wrapped in its link.
 * No templates, overlays, or text — whatever the merchant designed into
 * the artwork is what shows.
 */
export function HeroSlideCard({ slide }: { slide: HeroSlide }) {
  return (
    <Link
      href={slideHref(slide)}
      className="group block aspect-[16/10] w-full overflow-hidden rounded-lg bg-hero-panel shadow-floating transition-all duration-200 hover:shadow-menu focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="block size-full transition-transform duration-300 group-hover:scale-[1.03]">
        <ImageBox url={slide.imageUrl} alt="" fit="cover" placeholderColor="#EEE9E1" />
      </span>
    </Link>
  );
}
