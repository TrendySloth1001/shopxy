"use client";

import { useState, useCallback } from "react";
import { ChevronLeft, ChevronRight, Image as ImageIcon } from "lucide-react";
import { resolveImageUrl } from "@/features/home/format";
import type { ProductImage, ProductOffer } from "../types";

interface Props {
  images: ProductImage[];
  offers: ProductOffer[];
  productName: string;
}

export function PdpGallery({ images, offers, productName }: Props) {
  const [index, setIndex] = useState(0);
  const [errored, setErrored] = useState<Set<number>>(new Set());

  const couponOffer = offers.find((o) => o.kind === "COUPON");

  const prev = useCallback(() => setIndex((i) => (i > 0 ? i - 1 : images.length - 1)), [images.length]);
  const next = useCallback(() => setIndex((i) => (i < images.length - 1 ? i + 1 : 0)), [images.length]);

  if (images.length === 0) {
    return (
      // On desktop the gallery sits in a ~45% column (~580px at 1280px shell).
      // Cap at 420px so an empty placeholder doesn't swallow the viewport.
      <div className="flex aspect-square w-full items-center justify-center bg-canvas sm:aspect-[4/3] md:aspect-video lg:aspect-square lg:max-h-[420px]">
        <ImageIcon size={48} className="text-disabled" aria-hidden />
      </div>
    );
  }

  const current = images[index];
  const resolved = errored.has(index) ? "" : resolveImageUrl(current.url);

  return (
    <div className="relative w-full select-none">
      {/* Main image — on desktop cap at 420px so the buy-box stays visible above fold */}
      <div className="relative aspect-square w-full overflow-hidden bg-canvas sm:aspect-[4/3] md:aspect-video lg:aspect-square lg:max-h-[420px]">
        {resolved ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={resolved}
            alt={`${productName} image ${index + 1}`}
            className="size-full object-contain"
            onError={() => setErrored((s) => new Set([...s, index]))}
            draggable={false}
          />
        ) : (
          <div className="flex size-full items-center justify-center">
            <ImageIcon size={48} className="text-disabled" aria-hidden />
          </div>
        )}

        {/* Coupon pill */}
        {couponOffer ? (
          <div className="absolute bottom-md left-md flex items-center gap-xs rounded-full bg-error px-md py-xs shadow-snackbar">
            <span className="text-label-md text-white">{couponOffer.headline}</span>
            {couponOffer.code ? (
              <span className="text-label-md font-extrabold text-white">· {couponOffer.code}</span>
            ) : null}
          </div>
        ) : null}

        {/* Prev / next arrows — visible only when >1 image */}
        {images.length > 1 ? (
          <>
            <button
              onClick={prev}
              aria-label="Previous image"
              className="absolute left-sm top-1/2 flex size-8 -translate-y-1/2 items-center justify-center rounded-full bg-white/90 shadow-floating transition-opacity hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
            >
              <ChevronLeft size={18} className="text-ink" aria-hidden />
            </button>
            <button
              onClick={next}
              aria-label="Next image"
              className="absolute right-sm top-1/2 flex size-8 -translate-y-1/2 items-center justify-center rounded-full bg-white/90 shadow-floating transition-opacity hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
            >
              <ChevronRight size={18} className="text-ink" aria-hidden />
            </button>
          </>
        ) : null}
      </div>

      {/* Dot / thumbnail strip */}
      {images.length > 1 ? (
        <div className="flex items-center justify-center gap-xs py-sm">
          {images.map((img, i) => (
            <button
              key={i}
              onClick={() => setIndex(i)}
              aria-label={`View image ${i + 1}`}
              className={`rounded-full transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
                i === index
                  ? "h-[8px] w-[24px] bg-ink"
                  : "size-[8px] bg-hairline hover:bg-muted"
              }`}
            />
          ))}
        </div>
      ) : null}

      {/* Thumbnail row for desktop */}
      {images.length > 1 ? (
        <div className="hidden gap-xs overflow-x-auto px-lg pb-sm lg:flex">
          {images.map((img, i) => {
            const thumbUrl = errored.has(i) ? "" : resolveImageUrl(img.url);
            return (
              <button
                key={i}
                onClick={() => setIndex(i)}
                aria-label={`View image ${i + 1}`}
                className={`size-16 shrink-0 overflow-hidden rounded-sm border-2 transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
                  i === index ? "border-brand" : "border-hairline hover:border-muted"
                }`}
              >
                {thumbUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={thumbUrl}
                    alt={`Thumb ${i + 1}`}
                    className="size-full object-contain"
                    onError={() => setErrored((s) => new Set([...s, i]))}
                  />
                ) : (
                  <div className="flex size-full items-center justify-center bg-canvas">
                    <ImageIcon size={16} className="text-disabled" aria-hidden />
                  </div>
                )}
              </button>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}
