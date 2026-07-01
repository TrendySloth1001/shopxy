/**
 * Theme primitives shared by the no-flash boot script (imported into the server
 * `layout.tsx`) and the client `ThemeProvider`. Kept free of the `"use client"`
 * directive and of any React import so the server layout can pull the boot
 * script string without dragging client code into the server bundle.
 *
 * Eight themes, selected via the `data-theme` attribute on <html>; the CSS in
 * `globals.css` re-assigns the colour tokens per attribute value. Two families:
 *
 *   Light family (color-scheme: light — dark ink on a light ground):
 *     • light     — default warm-canvas look
 *     • beige     — soft sepia paper
 *     • rose      — warm blush / rosé
 *     • sage      — cool mint-green, calm
 *   Dark family (color-scheme: dark — light ink on a dark ground):
 *     • dark      — normal dark: deep-slate canvas, raised surfaces
 *     • oled      — true-black canvas for OLED panels (shares the dark palette)
 *     • midnight  — deep navy / indigo
 *     • nord      — muted arctic blue-grey
 *
 * Adding a theme is now a two-file change: append it to `THEMES` (and
 * `LIGHT_THEMES` if it's light-family) + a `THEME_META` entry here, and a
 * `html[data-theme="…"]` block in globals.css. The boot script and the type
 * guards below derive from `THEMES`, so they stay in sync automatically.
 */

/** Canonical order — also the order shown in the settings picker. The light
 *  family sits together ahead of the dark family. */
export const THEMES = [
  "light",
  "beige",
  "rose",
  "sage",
  "dark",
  "oled",
  "midnight",
  "nord",
] as const;

export type Theme = (typeof THEMES)[number];

/** The light-family themes — they report `color-scheme: light`; every other
 *  theme is dark. Keep in sync with `THEMES` when adding a light theme. */
export const LIGHT_THEMES: readonly Theme[] = ["light", "beige", "rose", "sage"];

/** localStorage key holding the user's choice (read by the boot script). */
export const THEME_STORAGE_KEY = "shopxy-theme";

export function isTheme(value: unknown): value is Theme {
  return (
    typeof value === "string" && (THEMES as readonly string[]).includes(value)
  );
}

/** Native `color-scheme` for the theme — drives form controls + scrollbars.
 *  The light family reports `light`; everything else reports `dark`. */
export function colorSchemeFor(theme: Theme): "light" | "dark" {
  return (LIGHT_THEMES as readonly string[]).includes(theme) ? "light" : "dark";
}

/** Apply a theme to <html> immediately (attribute + native colour-scheme). */
export function applyTheme(theme: Theme): void {
  if (typeof document === "undefined") return;
  const el = document.documentElement;
  el.dataset.theme = theme;
  el.style.colorScheme = colorSchemeFor(theme);
}

/** Read the theme the boot script already committed to the DOM (fallback for
 *  the very first client render so React state matches what's painted). */
export function readAppliedTheme(): Theme {
  if (typeof document === "undefined") return "light";
  const d = document.documentElement.dataset.theme;
  return isTheme(d) ? d : "light";
}

/**
 * Inline boot script — runs in <head> before first paint so the stored theme is
 * on <html> before any pixels land (no light-mode flash for dark users). Inlined
 * verbatim via dangerouslySetInnerHTML; keep it tiny, dependency-free and
 * exception-safe (private-mode localStorage throws).
 */
export const THEME_INIT_SCRIPT = `(function(){try{var v=${JSON.stringify(
  THEMES,
)};var l=${JSON.stringify(
  LIGHT_THEMES,
)};var t=localStorage.getItem(${JSON.stringify(
  THEME_STORAGE_KEY,
)});if(v.indexOf(t)<0)t="light";var e=document.documentElement;e.dataset.theme=t;e.style.colorScheme=(l.indexOf(t)>=0)?"light":"dark";}catch(e){}})();`;

/**
 * Display copy + a literal swatch triple for the settings picker. The swatch
 * intentionally carries raw hex (canvas / raised surface / ink) because each
 * tile must preview a *fixed* theme regardless of the one currently active —
 * the one place token utilities can't express the value. Mirrors the palettes
 * in `globals.css`; keep them in sync.
 */
export const THEME_META: Record<
  Theme,
  {
    label: string;
    description: string;
    swatch: { canvas: string; surface: string; ink: string };
  }
> = {
  light: {
    label: "Light",
    description: "Warm canvas, dark text — the default.",
    swatch: { canvas: "#f8f7f3", surface: "#ffffff", ink: "#14181d" },
  },
  beige: {
    label: "Beige",
    description: "Soft sepia paper — warm, low glare.",
    swatch: { canvas: "#ece3d1", surface: "#f8f2e6", ink: "#241f16" },
  },
  rose: {
    label: "Rose",
    description: "Warm blush — soft and easy on the eye.",
    swatch: { canvas: "#fbf0f2", surface: "#fff7f9", ink: "#3a2530" },
  },
  sage: {
    label: "Sage",
    description: "Cool mint-green — calm and quiet.",
    swatch: { canvas: "#eaf1ea", surface: "#f5faf5", ink: "#1c2b23" },
  },
  dark: {
    label: "Dark",
    description: "Deep slate surfaces, easy on the eyes.",
    swatch: { canvas: "#0f1419", surface: "#171d24", ink: "#e7eaee" },
  },
  oled: {
    label: "OLED",
    description: "True black — best for OLED displays.",
    swatch: { canvas: "#000000", surface: "#0c1014", ink: "#e7eaee" },
  },
  midnight: {
    label: "Midnight",
    description: "Deep navy — indigo-tinted dark.",
    swatch: { canvas: "#0d1220", surface: "#141b30", ink: "#e6e9f2" },
  },
  nord: {
    label: "Nord",
    description: "Muted arctic blue-grey — soft dark.",
    swatch: { canvas: "#2e3440", surface: "#3b4252", ink: "#e5e9f0" },
  },
};
