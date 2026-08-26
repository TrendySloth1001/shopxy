import { color } from "@/shared/ui/tokens";

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
  minimumFractionDigits: 0,
});

export function rupees(v: number): string {
  if (!Number.isFinite(v)) return "₹0";
  return inr.format(Math.round(v));
}

export function resolveImageUrl(url?: string | null): string {
  if (!url) return "";
  const trimmed = url.trim();
  if (trimmed === "") return "";
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  const path = trimmed.replace(/^\/+/, "");
  if (path.startsWith("images/")) return `/api/media/${path}`;
  return trimmed;
}

export function parseColor(hex: string | null | undefined, fallback: string): string {
  if (!hex) return fallback;
  const m = /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.exec(hex.trim());
  if (!m) return fallback;
  const raw = m[1];
  if (raw.length === 6) return `#${raw}`;
  const a = parseInt(raw.slice(0, 2), 16) / 255;
  const r = parseInt(raw.slice(2, 4), 16);
  const g = parseInt(raw.slice(4, 6), 16);
  const b = parseInt(raw.slice(6, 8), 16);
  return `rgba(${r}, ${g}, ${b}, ${a.toFixed(3)})`;
}

function toRgb(cssColor: string): { r: number; g: number; b: number } | null {
  const m = /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.exec(cssColor.trim());
  if (!m) return null;
  let raw = m[1];
  if (raw.length === 8) raw = raw.slice(2);
  return {
    r: parseInt(raw.slice(0, 2), 16),
    g: parseInt(raw.slice(2, 4), 16),
    b: parseInt(raw.slice(4, 6), 16),
  };
}

function luminance(cssColor: string): number {
  const rgb = toRgb(cssColor);
  if (!rgb) return 0.5;
  return (0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b) / 255;
}

export function autoFg(bgColor: string): string {
  return luminance(bgColor) > 0.55 ? color.ink.black : color.ink.white;
}

export function shade(cssColor: string, amount: number): string {
  const rgb = toRgb(cssColor);
  if (!rgb) return cssColor;
  const f = 1 - Math.max(0, Math.min(1, amount));
  const r = Math.round(rgb.r * f);
  const g = Math.round(rgb.g * f);
  const b = Math.round(rgb.b * f);
  return `rgb(${r}, ${g}, ${b})`;
}

export function withAlpha(cssColor: string, alpha: number): string {
  const rgb = toRgb(cssColor);
  if (rgb) return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${alpha})`;
  const m = /^rgba?\(([^)]+)\)/.exec(cssColor.trim());
  if (m) {
    const [r, g, b] = m[1].split(",").map((x) => x.trim());
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
  return cssColor;
}
