/**
 * Colour helpers for the slide preview. These operate on the merchant's
 * chosen hex values — i.e. *content*, not design-system tokens — so they
 * legitimately produce raw colour strings for inline `style`. They mirror
 * `_autoFg` / `_shade` in the Flutter `hero_slide_preview.dart` so the web
 * preview renders the same way the customer card will ship.
 */

const HEX_RE = /^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;

export function isHex(value: string): boolean {
  return HEX_RE.test(value.trim());
}

type Rgb = { r: number; g: number; b: number; a: number };

function parse(hex: string): Rgb | null {
  const v = hex.trim();
  if (!HEX_RE.test(v)) return null;
  const raw = v.slice(1);
  const r = parseInt(raw.slice(0, 2), 16);
  const g = parseInt(raw.slice(2, 4), 16);
  const b = parseInt(raw.slice(4, 6), 16);
  const a = raw.length === 8 ? parseInt(raw.slice(6, 8), 16) / 255 : 1;
  return { r, g, b, a };
}

/** Relative luminance (0..1), sRGB-ish — enough to pick a readable foreground. */
function luminance({ r, g, b }: Rgb): number {
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}

/** Black or white text for a given background, matching Flutter's 0.55 cut. */
export function autoFg(hex: string): string {
  const rgb = parse(hex);
  if (!rgb) return "#ffffff";
  return luminance(rgb) > 0.55 ? "#000000" : "#ffffff";
}

/** Darken toward black by `amount` (0..1). Used for the panel gradient. */
export function shade(hex: string, amount: number): string {
  const rgb = parse(hex);
  if (!rgb) return hex;
  const f = (c: number) => Math.max(0, Math.min(255, Math.round(c * (1 - amount))));
  return rgbToHex(f(rgb.r), f(rgb.g), f(rgb.b));
}

/** `rgba(...)` string for a hex at the given alpha (0..1). */
export function withAlpha(hex: string, alpha: number): string {
  const rgb = parse(hex);
  if (!rgb) return hex;
  return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${Math.max(0, Math.min(1, alpha))})`;
}

function rgbToHex(r: number, g: number, b: number): string {
  const h = (n: number) => n.toString(16).padStart(2, "0");
  return `#${h(r)}${h(g)}${h(b)}`;
}

/** Top-to-bottom panel gradient used by the solid-fill templates. */
export function panelGradient(hex: string): string {
  return `linear-gradient(to bottom, ${hex}, ${shade(hex, 0.08)})`;
}
