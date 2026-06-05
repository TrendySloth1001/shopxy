"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { SlideEditor } from "@/features/carousels/slide-editor";
import { carouselSchema, type Carousel } from "@/features/carousels/schema";
import { FormSkeleton } from "@/shared/ui/skeleton";

export default function NewSlidePage() {
  const params = useParams<{ id: string }>();
  const carouselId = Number(params.id);
  const [carousel, setCarousel] = useState<Carousel | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const res = await fetch(`/api/carousels/${carouselId}`, { cache: "no-store" });
        if (!res.ok) throw new Error();
        const c = carouselSchema.parse(await res.json());
        if (active) setCarousel(c);
      } catch {
        if (active) setError("Could not load the carousel.");
      }
    })();
    return () => {
      active = false;
    };
  }, [carouselId]);

  if (error) return <p className="w-full px-lg py-xxl text-body-sm text-error md:px-xxl">{error}</p>;
  if (!carousel) return <FormSkeleton />;

  return <SlideEditor carouselId={carouselId} carouselName={carousel.name} existing={null} />;
}
