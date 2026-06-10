import Link from "next/link";
import { ArrowRight } from "lucide-react";
import type { HeroSlide } from "../types";
import { autoFg, shade, withAlpha } from "../format";
import { ImageBox } from "./image-box";
import { searchHref } from "./product-carousel";

/** Tap destination for a banner slide. Banner-detail/collection pages are future work. */
export function slideHref(slide: HeroSlide): string {
  if (slide.bannerId) return `/banner/${slide.bannerId}`;
  const target = slide.ctaTarget ?? "";
  if (target.startsWith("collection:")) return searchHref(target.slice("collection:".length));
  return searchHref(slide.title || slide.brand || "");
}

function ctaLabel(slide: HeroSlide): string {
  const t = (slide.ctaText ?? "").trim();
  return t.length > 0 ? t : "Shop now";
}

function BrandMark({ slide, size = 26 }: { slide: HeroSlide; size?: number }) {
  if (slide.brandImageUrl) {
    return (
      <span
        className="inline-flex shrink-0 overflow-hidden rounded-full bg-white shadow-floating"
        style={{ width: size, height: size }}
      >
        <ImageBox url={slide.brandImageUrl} fit={slide.brandImageFit} placeholderColor="#FFFFFF" />
      </span>
    );
  }
  if (!slide.brand) return null;
  return (
    <span
      className="inline-flex items-center rounded-full px-[8px] py-[3px] text-[10px] font-extrabold tracking-[0.6px]"
      style={{ backgroundColor: slide.accent, color: autoFg(slide.accent) }}
    >
      {slide.brand.toUpperCase()}
    </span>
  );
}

function Pill({ label, bg, fg }: { label: string; bg: string; fg: string }) {
  return (
    <span
      className="inline-flex w-fit items-center gap-[6px] rounded-full px-[12px] py-[8px] text-[12px] font-extrabold tracking-[0.2px]"
      style={{ backgroundColor: bg, color: fg }}
    >
      {label}
      <ArrowRight size={14} aria-hidden />
    </span>
  );
}

/** A single banner card, rendered per the merchant-chosen template. */
export function HeroSlideCard({ slide }: { slide: HeroSlide }) {
  const fg = autoFg(slide.bgColor);
  const href = slideHref(slide);
  const inner = renderTemplate(slide, fg);
  return (
    <Link
      href={href}
      className="block aspect-[16/10] w-full overflow-hidden rounded-lg shadow-floating transition-shadow hover:shadow-menu focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      style={{ backgroundColor: slide.bgColor }}
    >
      {inner}
    </Link>
  );
}

function renderTemplate(slide: HeroSlide, fg: string) {
  switch (slide.template) {
    case "imageOnly":
      return <ImageOnly slide={slide} />;
    case "overlay":
      return <Overlay slide={slide} />;
    case "minimal":
      return <Minimal slide={slide} fg={fg} />;
    case "split":
      return <Split slide={slide} fg={fg} />;
    case "deal":
      return <Deal slide={slide} fg={fg} />;
    case "poster":
      return <Poster slide={slide} fg={fg} />;
    case "classic":
    default:
      return <Classic slide={slide} fg={fg} />;
  }
}

function Classic({ slide, fg }: { slide: HeroSlide; fg: string }) {
  return (
    <div className="relative size-full">
      <div className="absolute inset-y-0 right-0 w-[62%]">
        <ImageBox url={slide.imageUrl} alt={slide.title} fit={slide.imageFit} placeholderColor={slide.bgColor} />
      </div>
      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(to right, ${slide.bgColor} 32%, ${withAlpha(slide.bgColor, 0.95)} 55%, ${withAlpha(slide.bgColor, 0)} 95%)`,
        }}
      />
      <div className="relative flex size-full flex-col justify-center gap-[6px] p-lg" style={{ color: fg }}>
        <BrandMark slide={slide} size={28} />
        {slide.eyebrow ? (
          <p className="text-[10px] font-extrabold uppercase tracking-[1.2px]" style={{ color: withAlpha(fg, 0.72) }}>
            {slide.eyebrow}
          </p>
        ) : null}
        <p className="line-clamp-2 text-[26px] font-black leading-none tracking-[-0.5px]">{slide.title}</p>
        {slide.subtitle ? (
          <p className="text-[12px] leading-snug" style={{ color: withAlpha(fg, 0.78) }}>
            {slide.subtitle}
          </p>
        ) : null}
        <div className="mt-[2px]">
          <Pill label={ctaLabel(slide)} bg="#14181D" fg="#FFFFFF" />
        </div>
      </div>
    </div>
  );
}

function Minimal({ slide, fg }: { slide: HeroSlide; fg: string }) {
  return (
    <div className="flex size-full items-center gap-md p-lg" style={{ color: fg }}>
      <div className="flex min-w-0 flex-1 flex-col gap-[4px]">
        <BrandMark slide={slide} size={24} />
        {slide.eyebrow ? (
          <p className="text-[11px] italic" style={{ color: withAlpha(fg, 0.6) }}>
            {slide.eyebrow}
          </p>
        ) : null}
        <p className="line-clamp-2 text-[28px] font-black leading-none tracking-[-0.6px]">{slide.title}</p>
        {slide.subtitle ? (
          <p className="text-[12px] leading-snug" style={{ color: withAlpha(fg, 0.65) }}>
            {slide.subtitle}
          </p>
        ) : null}
        <div className="mt-[4px]">
          <Pill label={ctaLabel(slide)} bg={slide.accent} fg={autoFg(slide.accent)} />
        </div>
      </div>
      <div className="aspect-square h-full shrink-0 overflow-hidden rounded-full shadow-floating">
        <ImageBox url={slide.imageUrl} alt={slide.title} fit={slide.imageFit} placeholderColor={slide.bgColor} />
      </div>
    </div>
  );
}

function ImageOnly({ slide }: { slide: HeroSlide }) {
  return (
    <div className="relative size-full">
      <ImageBox url={slide.imageUrl} alt={slide.title} fit={slide.imageFit} placeholderColor={slide.bgColor} />
      <div
        className="absolute inset-0"
        style={{ background: "radial-gradient(circle at center, transparent 55%, rgba(0,0,0,0.18) 100%)" }}
      />
      <span className="absolute bottom-[6px] right-[6px] rounded-xs bg-white/70 px-[5px] py-[1px] text-[9px] font-bold tracking-[0.5px] text-muted">
        AD
      </span>
    </div>
  );
}

function Overlay({ slide }: { slide: HeroSlide }) {
  return (
    <div className="relative size-full">
      <ImageBox url={slide.imageUrl} alt={slide.title} fit={slide.imageFit} placeholderColor={slide.bgColor} />
      <div
        className="absolute inset-0"
        style={{
          background:
            "radial-gradient(circle at center, rgba(0,0,0,0.5), rgba(0,0,0,0.2) 90%), linear-gradient(to bottom, transparent 55%, rgba(0,0,0,0.35))",
        }}
      />
      <div className="absolute inset-0 flex flex-col items-center justify-center gap-[4px] p-md text-center text-white">
        <BrandMark slide={slide} size={26} />
        {slide.eyebrow ? <p className="text-[11px] italic text-white/90">{slide.eyebrow}</p> : null}
        <p className="line-clamp-2 text-[22px] font-black leading-tight tracking-[-0.5px] [text-shadow:0_2px_14px_rgba(0,0,0,0.4)]">
          {slide.title}
        </p>
        {slide.subtitle ? <p className="line-clamp-1 text-[11px] text-white/90">{slide.subtitle}</p> : null}
        <div className="mt-[2px]">
          <Pill label={ctaLabel(slide)} bg="#FFFFFF" fg="#14181D" />
        </div>
      </div>
    </div>
  );
}

function Split({ slide, fg }: { slide: HeroSlide; fg: string }) {
  return (
    <div className="flex size-full">
      <div
        className="flex flex-1 flex-col justify-center gap-[4px] p-lg"
        style={{ color: fg, background: `linear-gradient(to bottom, ${slide.bgColor}, ${shade(slide.bgColor, 0.08)})` }}
      >
        <BrandMark slide={slide} size={24} />
        {slide.eyebrow ? (
          <p className="text-[11px] italic" style={{ color: withAlpha(fg, 0.6) }}>
            {slide.eyebrow}
          </p>
        ) : null}
        <p className="line-clamp-2 text-[26px] font-black leading-none tracking-[-0.5px]">{slide.title}</p>
        {slide.subtitle ? (
          <p className="text-[12px] leading-snug" style={{ color: withAlpha(fg, 0.8) }}>
            {slide.subtitle}
          </p>
        ) : null}
        <div className="mt-[4px]">
          <Pill label={ctaLabel(slide)} bg={slide.accent} fg={autoFg(slide.accent)} />
        </div>
      </div>
      <div className="relative flex-1">
        <ImageBox url={slide.imageUrl} alt={slide.title} fit={slide.imageFit} placeholderColor={slide.bgColor} />
        <div
          className="absolute inset-0"
          style={{ background: `linear-gradient(to right, ${withAlpha(slide.bgColor, 0.55)}, transparent 35%)` }}
        />
      </div>
    </div>
  );
}

function Deal({ slide, fg }: { slide: HeroSlide; fg: string }) {
  const badge = (slide.eyebrow ?? "").trim();
  const m = /(\d+%?)/.exec(badge);
  return (
    <div className="relative size-full">
      <div className="absolute inset-y-0 right-0 w-[62%]">
        <ImageBox url={slide.imageUrl} alt={slide.title} fit="cover" placeholderColor={slide.bgColor} />
      </div>
      <div
        className="absolute inset-0"
        style={{ background: `linear-gradient(to right, ${slide.bgColor} 40%, ${withAlpha(slide.bgColor, 0)} 85%)` }}
      />
      {badge ? (
        <div
          className="absolute left-lg top-lg rounded-md px-[14px] py-[10px] text-white shadow-menu"
          style={{ background: `linear-gradient(to bottom right, ${slide.accent}, ${shade(slide.accent, 0.22)})` }}
        >
          {m ? (
            <span className="flex items-end gap-[3px]">
              <span className="text-[36px] font-black leading-none tracking-[-1px]">{m[1]}</span>
              <span className="pb-[3px] text-[12px] font-black uppercase tracking-[1.5px]">
                {badge.replace(m[1], "").trim() || "off"}
              </span>
            </span>
          ) : (
            <span className="text-[22px] font-black">{badge}</span>
          )}
        </div>
      ) : null}
      <div className="relative flex size-full flex-col justify-end gap-[4px] p-lg" style={{ color: fg }}>
        <p className="text-[26px] font-black leading-none tracking-[-0.5px]">{slide.title}</p>
        {slide.subtitle ? (
          <p className="text-[12px]" style={{ color: withAlpha(fg, 0.8) }}>
            {slide.subtitle}
          </p>
        ) : null}
        <div className="mt-[4px]">
          <Pill label={ctaLabel(slide)} bg={slide.accent} fg={autoFg(slide.accent)} />
        </div>
      </div>
    </div>
  );
}

function Poster({ slide, fg }: { slide: HeroSlide; fg: string }) {
  return (
    <div className="flex size-full flex-col">
      <div className="relative h-[60%] w-full">
        <ImageBox url={slide.imageUrl} alt={slide.title} fit={slide.imageFit} placeholderColor={slide.bgColor} />
        <div
          className="absolute inset-0"
          style={{ background: `linear-gradient(to bottom, transparent 65%, ${withAlpha(slide.bgColor, 0.55)})` }}
        />
      </div>
      <div
        className="flex h-[40%] items-center gap-md px-md py-sm"
        style={{ color: fg, background: `linear-gradient(to bottom, ${slide.bgColor}, ${shade(slide.bgColor, 0.08)})` }}
      >
        <div className="flex min-w-0 flex-1 flex-col gap-[2px]">
          <BrandMark slide={slide} size={22} />
          <p className="line-clamp-1 text-[20px] font-black leading-tight tracking-[-0.4px]">{slide.title}</p>
          {slide.subtitle ? (
            <p className="line-clamp-1 text-[11px]" style={{ color: withAlpha(fg, 0.7) }}>
              {slide.subtitle}
            </p>
          ) : null}
        </div>
        <Pill label={ctaLabel(slide)} bg={slide.accent} fg={autoFg(slide.accent)} />
      </div>
    </div>
  );
}
