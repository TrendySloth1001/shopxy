import {
  carouselListSchema,
  carouselSchema,
  slideListSchema,
  slideSchema,
  type Carousel,
  type ImageFit,
  type Placement,
  type Slide,
  type Template,
} from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

// ── Carousels ───────────────────────────────────────────────────────────
export type CarouselCreate = {
  name: string;
  placement: Placement;
  isActive?: boolean;
  startAt?: string | null;
  endAt?: string | null;
};
export type CarouselUpdate = Partial<CarouselCreate>;

export function listCarousels(): Promise<Carousel[]> {
  return fetch("/api/carousels", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => carouselListSchema.parse(raw).data, "Could not load carousels."),
  );
}

export function createCarousel(input: CarouselCreate): Promise<Carousel> {
  return fetch("/api/carousels", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => carouselSchema.parse(raw), "Could not create the carousel."));
}

export function updateCarousel(id: number, input: CarouselUpdate): Promise<Carousel> {
  return fetch(`/api/carousels/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => carouselSchema.parse(raw), "Could not save the carousel."));
}

export async function deleteCarousel(id: number): Promise<void> {
  const res = await fetch(`/api/carousels/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, () => null, "Could not delete the carousel.");
  }
}

// ── Slides ──────────────────────────────────────────────────────────────
export type SlideWrite = {
  template?: Template;
  imageFit?: ImageFit;
  title?: string;
  subtitle?: string | null;
  eyebrow?: string | null;
  ctaText?: string | null;
  ctaTarget?: string | null;
  brandLabel?: string | null;
  brandImageUrl?: string | null;
  brandImageFit?: ImageFit;
  imageUrl?: string;
  bgColor?: string;
  accentColor?: string | null;
  sortOrder?: number;
  startAt?: string | null;
  endAt?: string | null;
  isActive?: boolean;
};

export function listSlides(carouselId: number): Promise<Slide[]> {
  return fetch(`/api/carousels/${carouselId}/slides`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => slideListSchema.parse(raw).data, "Could not load slides."),
  );
}

export function createSlide(carouselId: number, input: SlideWrite): Promise<Slide> {
  return fetch(`/api/carousels/${carouselId}/slides`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => slideSchema.parse(raw), "Could not create the slide."));
}

export function updateSlide(carouselId: number, slideId: number, input: SlideWrite): Promise<Slide> {
  return fetch(`/api/carousels/${carouselId}/slides/${slideId}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => slideSchema.parse(raw), "Could not save the slide."));
}

export async function deleteSlide(carouselId: number, slideId: number): Promise<void> {
  const res = await fetch(`/api/carousels/${carouselId}/slides/${slideId}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, () => null, "Could not delete the slide.");
  }
}
