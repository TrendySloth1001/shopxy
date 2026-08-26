import Link from "next/link";
import type { HeroSlide } from "../types";
import { ImageBox } from "./image-box";

export function slideHref(slide: HeroSlide): string {
  if (slide.productCount > 0) return `/banner/${slide.bannerId}`;
  return slide.linkUrl && slide.linkUrl.length > 0 ? slide.linkUrl : "/";
}

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
