import { z } from "zod";

/**
 * Carousel + slide (Banner) shapes, mirroring the backend `carousels` module's
 * `carouselSelect` / `slideSelect`. A carousel is a placement-scoped container;
 * its slides are Banner rows with the rich templated content.
 */

// ── Placement ───────────────────────────────────────────────────────────
export const PLACEMENTS = ["HERO", "AD_STRIP", "PROMO", "CURATED_RAIL"] as const;
export type Placement = (typeof PLACEMENTS)[number];

export const PLACEMENT_LABELS: Record<Placement, string> = {
  HERO: "Hero carousel",
  AD_STRIP: "Ad strip",
  PROMO: "Promo banner",
  CURATED_RAIL: "Curated rail",
};

// ── Template ────────────────────────────────────────────────────────────
export const TEMPLATES = [
  "CLASSIC",
  "MINIMAL",
  "IMAGE_ONLY",
  "SPLIT",
  "OVERLAY",
  "DEAL",
  "POSTER",
] as const;
export type Template = (typeof TEMPLATES)[number];

export const TEMPLATE_LABELS: Record<Template, string> = {
  CLASSIC: "Classic",
  MINIMAL: "Minimal",
  IMAGE_ONLY: "Image only",
  SPLIT: "Split",
  OVERLAY: "Overlay",
  DEAL: "Deal",
  POSTER: "Poster",
};

export const TEMPLATE_DESCRIPTIONS: Record<Template, string> = {
  CLASSIC: "Brand chip, headline, subtitle and a Shop now button overlaid on your photo.",
  MINIMAL: "Centered headline with a small accent label and a circular product medallion.",
  IMAGE_ONLY: "Just your uploaded image, edge to edge. No headline or buttons added.",
  SPLIT: "Solid colour panel on one side with your text and button, photo on the other half.",
  OVERLAY: "Full-bleed image with a dark scrim. Centered white text — works on any photo.",
  DEAL: "Big deal badge in the corner, product hero on the right. Use the brand label as the deal text.",
  POSTER: "Image on top, solid colour panel below with title and accent chip. Movie-poster style.",
};

/** Image-only carries its own copy, so the text/colour controls are hidden. */
export function templateSupportsText(t: Template): boolean {
  return t !== "IMAGE_ONLY";
}
export function templateSupportsSubtitle(t: Template): boolean {
  return t !== "IMAGE_ONLY";
}
export function templateSupportsColors(t: Template): boolean {
  return t !== "IMAGE_ONLY";
}

// ── Image fit ───────────────────────────────────────────────────────────
export const IMAGE_FITS = ["COVER", "CONTAIN"] as const;
export type ImageFit = (typeof IMAGE_FITS)[number];

export const IMAGE_FIT_LABELS: Record<ImageFit, string> = {
  COVER: "Fill",
  CONTAIN: "Fit",
};

// ── Carousel ────────────────────────────────────────────────────────────
export const carouselSchema = z
  .object({
    id: z.number(),
    shopId: z.number().nullish(),
    name: z.string(),
    placement: z.enum(PLACEMENTS),
    isActive: z.boolean().default(true),
    startAt: z.string().nullish(),
    endAt: z.string().nullish(),
    sortOrder: z.coerce.number().default(0),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
    _count: z.object({ slides: z.coerce.number().default(0) }).nullish(),
  })
  .passthrough();
export type Carousel = z.infer<typeof carouselSchema>;

export const carouselListSchema = z.object({
  data: z.array(carouselSchema).nullish().transform((v) => v ?? []),
});

// ── Slide ───────────────────────────────────────────────────────────────
export const slideSchema = z
  .object({
    id: z.number(),
    carouselId: z.number(),
    placement: z.enum(PLACEMENTS).nullish(),
    template: z.enum(TEMPLATES).default("CLASSIC"),
    imageFit: z.enum(IMAGE_FITS).default("COVER"),
    title: z.string(),
    subtitle: z.string().nullish(),
    eyebrow: z.string().nullish(),
    ctaText: z.string().nullish(),
    ctaTarget: z.string().nullish(),
    brandLabel: z.string().nullish(),
    brandImageUrl: z.string().nullish(),
    brandImageFit: z.enum(IMAGE_FITS).default("COVER"),
    imageUrl: z.string(),
    bgColor: z.string(),
    accentColor: z.string().nullish(),
    sortOrder: z.coerce.number().default(0),
    startAt: z.string().nullish(),
    endAt: z.string().nullish(),
    isActive: z.boolean().default(true),
    sponsorShopId: z.number().nullish(),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
  })
  .passthrough();
export type Slide = z.infer<typeof slideSchema>;

export const slideListSchema = z.object({
  data: z.array(slideSchema).nullish().transform((v) => v ?? []),
});
