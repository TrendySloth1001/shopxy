import { z } from 'zod';

// Hex color shared by templated and freeform fields. 7-char `#RRGGBB` or
// 9-char `#RRGGBBAA` — keeps the serialiser happy and matches the
// existing `hexColor` zod in banners.controller.ts.
const hexColor = z
  .string()
  .regex(/^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/, 'Must be hex like #RRGGBB');

/// One freeform text block on a FREEFORM slide. Positioning is
/// percent-of-canvas (`xPct`/`yPct`/`widthPct`) so the customer
/// renderer is resolution-independent. Every numeric axis is bounded
/// before write to prevent off-canvas or absurdly large text.
export const textBlockSchema = z.object({
  /// Stable id supplied by the editor so reorders + edits don't drop
  /// blocks across saves. Free-form string; we don't interpret it.
  id: z.string().min(1).max(64),
  text: z.string().min(1).max(200),
  xPct: z.number().min(0).max(100),
  yPct: z.number().min(0).max(100),
  widthPct: z.number().min(5).max(100),
  /// Bounded by the editor — the 8px floor keeps the renderer from
  /// shipping invisible text; the 96px ceiling keeps a single block
  /// from blowing past the card height on small phones.
  fontSize: z.number().int().min(8).max(96),
  color: hexColor,
  weight: z.union([
    z.literal(400),
    z.literal(500),
    z.literal(600),
    z.literal(700),
    z.literal(800),
    z.literal(900),
  ]),
  align: z.enum(['left', 'center', 'right']),
});

export const textBlocksSchema = z.array(textBlockSchema).max(8);

/// Per-slide image transform — FREEFORM only. TEMPLATED slides ignore
/// these and rely on `imageFit` for the basic COVER/CONTAIN choice.
export const imageTransformSchema = z.object({
  /// Focal point in image-percent coordinates. The renderer aligns this
  /// point to the centre of its slot, so 50/50 = "centre". Used by COVER
  /// (default) to control which part of the image survives the crop.
  focalXPct: z.number().min(0).max(100).default(50),
  focalYPct: z.number().min(0).max(100).default(50),
  /// Multiplier on top of `imageFit`'s base sizing. 1.0 = as-is. The
  /// 4× cap keeps a malicious payload from rendering a 4000px slot.
  scale: z.number().min(0.25).max(4).default(1),
  rotateDeg: z.number().min(-180).max(180).default(0),
  flipH: z.boolean().default(false),
  flipV: z.boolean().default(false),
  /// CSS-style colour-filter axes. 1.0 = neutral. Bounded so a bad
  /// payload can't render a completely white or black slot.
  brightness: z.number().min(0.5).max(1.5).default(1),
  contrast: z.number().min(0.5).max(1.5).default(1),
  saturation: z.number().min(0.5).max(1.5).default(1),
});

export type TextBlock = z.infer<typeof textBlockSchema>;
export type ImageTransform = z.infer<typeof imageTransformSchema>;
