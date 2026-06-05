"use client";

import Image from "next/image";
import { mediaSrc } from "@/features/products/components/product-thumb";
import { autoFg, panelGradient, withAlpha } from "./color";
import type { ImageFit, Template } from "./schema";

/**
 * Live slide preview — the web mirror of the customer-side hero card so the
 * merchant sees exactly what ships. Renders all seven Banner templates. Colours
 * come from the merchant's hex values (content, not tokens), so the templated
 * text/gradients use inline styles. Layout follows
 * `frontend/lib/features/carousel/presentation/widgets/hero_slide_preview.dart`.
 */
export type SlidePreviewData = {
  template: Template;
  imageFit: ImageFit;
  title: string;
  subtitle?: string | null;
  eyebrow?: string | null;
  brandLabel?: string | null;
  brandImageUrl?: string | null;
  brandImageFit?: ImageFit;
  ctaText?: string | null;
  imageUrl?: string | null;
  bgColor: string;
  accentColor: string;
};

const resolved = (d: SlidePreviewData) => ({
  cta: d.ctaText?.trim() || "Shop now",
  brand: d.brandLabel?.trim() ?? "",
  subtitle: d.subtitle?.trim() ?? "",
  eyebrow: d.eyebrow?.trim() ?? "",
  hasBrandImage: !!(d.brandImageUrl ?? "").trim(),
  title: d.title.trim() || "Your slide title",
});

export function HeroSlidePreview({
  data,
  aspect = "16 / 7",
}: {
  data: SlidePreviewData;
  aspect?: string;
}) {
  return (
    <div
      className="relative w-full overflow-hidden rounded-lg shadow-floating"
      style={{ aspectRatio: aspect }}
    >
      <SlideBody data={data} />
    </div>
  );
}

function SlideBody({ data }: { data: SlidePreviewData }) {
  switch (data.template) {
    case "IMAGE_ONLY":
      return <ImageOnlyCard data={data} />;
    case "MINIMAL":
      return <MinimalCard data={data} />;
    case "SPLIT":
      return <SplitCard data={data} />;
    case "OVERLAY":
      return <OverlayCard data={data} />;
    case "DEAL":
      return <DealCard data={data} />;
    case "POSTER":
      return <PosterCard data={data} />;
    case "CLASSIC":
    default:
      return <ClassicCard data={data} />;
  }
}

// ── Shared pieces ─────────────────────────────────────────────────────────

function SlideImage({ url, fit, bg }: { url?: string | null; fit: ImageFit; bg: string }) {
  const src = mediaSrc(url);
  return (
    <div className="absolute inset-0" style={{ backgroundColor: bg }}>
      {src ? (
        <Image
          src={src}
          alt=""
          fill
          unoptimized
          sizes="640px"
          className={fit === "CONTAIN" ? "object-contain" : "object-cover"}
        />
      ) : null}
    </div>
  );
}

function Pill({ label, bg, fg }: { label: string; bg: string; fg: string }) {
  return (
    <span
      className="inline-block rounded-full px-md py-xs text-body-sm font-extrabold shadow-floating"
      style={{ backgroundColor: bg, color: fg }}
    >
      {label}
    </span>
  );
}

function BrandMark({
  data,
  size,
  chip,
  center,
}: {
  data: SlidePreviewData;
  size: number;
  chip: React.ReactNode;
  center?: boolean;
}) {
  const r = resolved(data);
  const logoSrc = mediaSrc(data.brandImageUrl);
  const logo = r.hasBrandImage && logoSrc ? (
    <span
      className="relative inline-block shrink-0 overflow-hidden rounded-full bg-white shadow-floating"
      style={{ width: size, height: size }}
    >
      <Image
        src={logoSrc}
        alt=""
        fill
        unoptimized
        sizes={`${size}px`}
        className={data.brandImageFit === "CONTAIN" ? "object-contain" : "object-cover"}
      />
    </span>
  ) : null;
  const label = r.brand ? chip : null;
  if (!logo && !label) return null;
  if (logo && label) {
    return (
      <span className={`flex items-center gap-sm ${center ? "justify-center" : ""}`}>
        {logo}
        {label}
      </span>
    );
  }
  return <>{logo ?? label}</>;
}

// ── Templates ─────────────────────────────────────────────────────────────

function ClassicCard({ data }: { data: SlidePreviewData }) {
  const r = resolved(data);
  const fg = autoFg(data.bgColor);
  return (
    <div className="absolute inset-0" style={{ background: panelGradient(data.bgColor) }}>
      <div className="absolute inset-y-0 right-0 w-[62%]">
        <SlideImage url={data.imageUrl} fit={data.imageFit} bg={data.bgColor} />
      </div>
      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(to right, ${data.bgColor} 32%, ${withAlpha(
            data.bgColor,
            0.95,
          )} 55%, ${withAlpha(data.bgColor, 0)} 95%)`,
        }}
      />
      <div className="absolute inset-0 flex flex-col justify-center gap-xs p-lg">
        <div className="max-w-[58%]">
          <BrandMark
            data={data}
            size={28}
            chip={
              <span
                className="inline-block rounded-full px-sm py-px text-body-sm font-extrabold uppercase tracking-wide text-white"
                style={{ backgroundColor: data.accentColor }}
              >
                {r.brand}
              </span>
            }
          />
          {r.eyebrow ? (
            <p
              className="mt-xs text-label-md font-bold uppercase tracking-wide"
              style={{ color: withAlpha(fg, 0.72) }}
            >
              {r.eyebrow}
            </p>
          ) : null}
          <p
            className="mt-xs line-clamp-2 text-headline-sm font-black leading-none tracking-tight"
            style={{ color: fg }}
          >
            {r.title}
          </p>
          {r.subtitle ? (
            <p className="mt-xs line-clamp-2 text-body-sm" style={{ color: withAlpha(fg, 0.78) }}>
              {r.subtitle}
            </p>
          ) : null}
          <div className="mt-sm">
            <Pill label={r.cta} bg="#000000" fg="#ffffff" />
          </div>
        </div>
      </div>
    </div>
  );
}

function MinimalCard({ data }: { data: SlidePreviewData }) {
  const r = resolved(data);
  const fg = autoFg(data.bgColor);
  return (
    <div className="absolute inset-0 flex items-center gap-md p-lg" style={{ background: panelGradient(data.bgColor) }}>
      <div className="min-w-0 flex-1">
        <BrandMark
          data={data}
          size={24}
          chip={
            <span
              className="text-label-md font-bold uppercase tracking-widest"
              style={{ color: data.accentColor }}
            >
              {r.brand}
            </span>
          }
        />
        {r.eyebrow ? (
          <p className="mt-px text-label-md italic" style={{ color: withAlpha(fg, 0.6) }}>
            {r.eyebrow}
          </p>
        ) : null}
        <p
          className="mt-xs line-clamp-2 text-headline-sm font-black leading-none tracking-tight"
          style={{ color: fg }}
        >
          {r.title}
        </p>
        {r.subtitle ? (
          <p className="mt-xs line-clamp-2 text-body-sm" style={{ color: withAlpha(fg, 0.65) }}>
            {r.subtitle}
          </p>
        ) : null}
        <div className="mt-sm">
          <Pill label={r.cta} bg={data.accentColor} fg="#ffffff" />
        </div>
      </div>
      <div className="relative aspect-square w-[32%] shrink-0 self-center overflow-hidden rounded-full shadow-floating">
        <SlideImage url={data.imageUrl} fit={data.imageFit} bg={data.bgColor} />
      </div>
    </div>
  );
}

function ImageOnlyCard({ data }: { data: SlidePreviewData }) {
  return (
    <div className="absolute inset-0">
      <SlideImage url={data.imageUrl} fit={data.imageFit} bg={data.bgColor} />
      <div
        className="absolute inset-0"
        style={{ background: "radial-gradient(circle at 50% 45%, transparent 58%, rgba(0,0,0,0.20))" }}
      />
    </div>
  );
}

function SplitCard({ data }: { data: SlidePreviewData }) {
  const r = resolved(data);
  const fg = autoFg(data.bgColor);
  return (
    <div className="absolute inset-0 flex">
      <div
        className="flex min-w-0 flex-1 flex-col justify-center gap-xs p-lg"
        style={{ background: panelGradient(data.bgColor) }}
      >
        <BrandMark
          data={data}
          size={24}
          chip={
            <span
              className="text-label-md font-bold uppercase tracking-widest"
              style={{ color: data.accentColor }}
            >
              {r.brand}
            </span>
          }
        />
        {r.eyebrow ? (
          <p className="text-label-md italic" style={{ color: withAlpha(fg, 0.6) }}>
            {r.eyebrow}
          </p>
        ) : null}
        <p
          className="line-clamp-2 text-headline-sm font-black leading-none tracking-tight"
          style={{ color: fg }}
        >
          {r.title}
        </p>
        {r.subtitle ? (
          <p className="line-clamp-2 text-body-sm" style={{ color: withAlpha(fg, 0.8) }}>
            {r.subtitle}
          </p>
        ) : null}
        <div className="mt-xs">
          <Pill label={r.cta} bg={data.accentColor} fg="#ffffff" />
        </div>
      </div>
      <div className="relative min-w-0 flex-1">
        <SlideImage url={data.imageUrl} fit={data.imageFit} bg={data.bgColor} />
        <div
          className="absolute inset-0"
          style={{
            background: `linear-gradient(to right, ${withAlpha(data.bgColor, 0.55)}, ${withAlpha(
              data.bgColor,
              0,
            )} 35%)`,
          }}
        />
      </div>
    </div>
  );
}

function OverlayCard({ data }: { data: SlidePreviewData }) {
  const r = resolved(data);
  return (
    <div className="absolute inset-0">
      <SlideImage url={data.imageUrl} fit={data.imageFit} bg={data.bgColor} />
      <div
        className="absolute inset-0"
        style={{ background: "radial-gradient(circle at 50% 50%, rgba(0,0,0,0.50), rgba(0,0,0,0.20))" }}
      />
      <div
        className="absolute inset-0"
        style={{ background: "linear-gradient(to bottom, transparent 55%, rgba(0,0,0,0.35))" }}
      />
      <div className="absolute inset-0 flex flex-col items-center justify-center gap-xs p-md text-center">
        <BrandMark
          data={data}
          size={26}
          center
          chip={
            <span className="text-label-md font-bold uppercase tracking-widest text-white">{r.brand}</span>
          }
        />
        {r.eyebrow ? <p className="text-label-md italic text-white/90">{r.eyebrow}</p> : null}
        <p className="line-clamp-2 text-headline-sm font-black leading-tight tracking-tight text-white drop-shadow">
          {r.title}
        </p>
        {r.subtitle ? <p className="text-body-sm text-white/90">{r.subtitle}</p> : null}
        <div className="mt-xs">
          <Pill label={r.cta} bg="#ffffff" fg="#000000" />
        </div>
      </div>
    </div>
  );
}

function DealCard({ data }: { data: SlidePreviewData }) {
  const r = resolved(data);
  const fg = autoFg(data.bgColor);
  const dealText = r.brand ? r.brand.toUpperCase() : "DEAL";
  return (
    <div className="absolute inset-0" style={{ background: panelGradient(data.bgColor) }}>
      <div className="absolute inset-y-0 right-0 w-[62%]">
        <SlideImage url={data.imageUrl} fit={data.imageFit} bg={data.bgColor} />
      </div>
      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(to right, ${data.bgColor} 40%, ${withAlpha(data.bgColor, 0)} 85%)`,
        }}
      />
      <span
        className="absolute left-lg top-lg rounded-md px-sm py-xs text-body-sm font-extrabold uppercase tracking-wide text-white shadow-floating"
        style={{ backgroundColor: data.accentColor }}
      >
        {dealText}
      </span>
      <div className="absolute inset-0 flex flex-col justify-end gap-xs p-lg">
        <div className="max-w-[58%]">
          {r.eyebrow ? (
            <p
              className="text-label-md font-bold uppercase tracking-wide"
              style={{ color: withAlpha(fg, 0.72) }}
            >
              {r.eyebrow}
            </p>
          ) : null}
          <p
            className="line-clamp-2 text-headline-sm font-black leading-none tracking-tight"
            style={{ color: fg }}
          >
            {r.title}
          </p>
          {r.subtitle ? (
            <p className="line-clamp-2 text-body-sm" style={{ color: withAlpha(fg, 0.8) }}>
              {r.subtitle}
            </p>
          ) : null}
          <div className="mt-sm">
            <Pill label={r.cta} bg={data.accentColor} fg="#ffffff" />
          </div>
        </div>
      </div>
    </div>
  );
}

function PosterCard({ data }: { data: SlidePreviewData }) {
  const r = resolved(data);
  const fg = autoFg(data.bgColor);
  return (
    <div className="absolute inset-0 flex flex-col">
      <div className="relative min-h-0 flex-[6]">
        <SlideImage url={data.imageUrl} fit={data.imageFit} bg={data.bgColor} />
        <div
          className="absolute inset-0"
          style={{
            background: `linear-gradient(to bottom, transparent 65%, ${withAlpha(data.bgColor, 0.55)})`,
          }}
        />
      </div>
      <div
        className="flex min-h-0 flex-[4] items-center gap-md px-md py-sm"
        style={{ background: panelGradient(data.bgColor) }}
      >
        <div className="min-w-0 flex-1">
          <BrandMark
            data={data}
            size={22}
            chip={
              <span
                className="text-label-md font-bold uppercase tracking-wide"
                style={{ color: data.accentColor }}
              >
                {r.brand}
              </span>
            }
          />
          {r.eyebrow ? (
            <p className="truncate text-label-md italic" style={{ color: withAlpha(fg, 0.6) }}>
              {r.eyebrow}
            </p>
          ) : null}
          <p className="truncate text-title-sm font-black leading-tight tracking-tight" style={{ color: fg }}>
            {r.title}
          </p>
          {r.subtitle ? (
            <p className="truncate text-label-md" style={{ color: withAlpha(fg, 0.7) }}>
              {r.subtitle}
            </p>
          ) : null}
        </div>
        <Pill label={r.cta} bg={data.accentColor} fg="#ffffff" />
      </div>
    </div>
  );
}
