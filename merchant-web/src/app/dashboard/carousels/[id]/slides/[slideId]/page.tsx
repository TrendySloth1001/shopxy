"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { SlideEditor } from "@/features/carousels/slide-editor";
import { getSlide } from "@/features/carousels/api";
import { carouselSchema, type Carousel, type Slide } from "@/features/carousels/schema";

export default function EditSlidePage() {
  const params = useParams<{ id: string; slideId: string }>();
  const carouselId = Number(params.id);
  const slideId = Number(params.slideId);
  const [carousel, setCarousel] = useState<Carousel | null>(null);
  const [slide, setSlide] = useState<Slide | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const res = await fetch(`/api/carousels/${carouselId}`, { cache: "no-store" });
        if (!res.ok) throw new Error();
        const c = carouselSchema.parse(await res.json());
        const s = await getSlide(carouselId, slideId);
        if (!active) return;
        setCarousel(c);
        setSlide(s);
      } catch {
        if (active) setError("Could not load the slide.");
      }
    })();
    return () => {
      active = false;
    };
  }, [carouselId, slideId]);

  if (error) return <p className="w-full px-lg py-xxl text-body-sm text-error md:px-xxl">{error}</p>;
  if (!carousel || !slide)
    return <p className="w-full px-lg py-xxl text-body-sm text-subtle md:px-xxl">Loading…</p>;

  return <SlideEditor carouselId={carouselId} carouselName={carousel.name} existing={slide} />;
}
